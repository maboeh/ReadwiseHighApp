import Foundation
import SwiftUI
import Security
import CommonCrypto

// MARK: - Certificate Pinning

/// URLSession-Delegate für Certificate Pinning
/// Schützt gegen Man-in-the-Middle (MITM) Angriffe
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    /// Die gepinnten Domains und ihre Public Key Hashes (SHA256, Base64-encoded)
    /// WICHTIG: Diese Hashes müssen aktualisiert werden, wenn readwise.io sein Zertifikat erneuert
    /// Aktueller Hash kann mit folgendem Befehl ermittelt werden:
    /// openssl s_client -connect readwise.io:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | base64
    private let pinnedHosts: [String: Set<String>] = [
        "readwise.io": [
            // Primärer Public Key Hash (aktuelles Zertifikat)
            // Backup-Hash (für Zertifikatswechsel - sollte der CA-Public-Key sein)
            // Hinweis: In Produktion sollten hier echte Hashes stehen
            // Für Entwicklung/Testing wird Pinning bei fehlenden Hashes übersprungen
        ]
    ]

    /// Gibt an, ob Certificate Pinning aktiviert ist
    /// In Debug-Builds kann dies deaktiviert werden für einfacheres Testing
    #if DEBUG
    private let pinningEnabled = false // Für Entwicklung deaktiviert
    #else
    private let pinningEnabled = true  // In Produktion aktiviert
    #endif

    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        // Nur Server-Trust-Challenges behandeln
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host

        // Wenn Pinning deaktiviert ist oder kein Host gepinnt ist, Standard-Validierung verwenden
        guard pinningEnabled,
              let pinnedHashes = pinnedHosts[host],
              !pinnedHashes.isEmpty else {
            // Standard-SSL-Validierung durchführen
            if SecTrustEvaluateWithError(serverTrust, nil) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        // Zertifikatskette validieren
        guard SecTrustEvaluateWithError(serverTrust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Public Key aus dem Server-Zertifikat extrahieren und hashen
        if let serverPublicKeyHash = extractPublicKeyHash(from: serverTrust) {
            if pinnedHashes.contains(serverPublicKeyHash) {
                // Hash stimmt überein - Verbindung erlauben
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        // Kein passender Hash gefunden - Verbindung ablehnen
        #if DEBUG
        debugLog("Certificate Pinning fehlgeschlagen für Host: \(host)")
        #endif
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    /// Extrahiert den SHA256-Hash des Public Keys aus dem Server-Trust
    private func extractPublicKeyHash(from serverTrust: SecTrust) -> String? {
        // Erstes Zertifikat (Server-Zertifikat) holen
        guard let certificate = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
              let serverCert = certificate.first else {
            return nil
        }

        // Public Key extrahieren
        guard let publicKey = SecCertificateCopyKey(serverCert) else {
            return nil
        }

        // Public Key als Daten exportieren
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        // SHA256-Hash berechnen
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        // Base64-kodiert zurückgeben
        return Data(hash).base64EncodedString()
    }
}

/// Debug-Logging Funktion (nur in DEBUG-Builds aktiv)
func debugLog(_ message: String, file: String = #file, line: Int = #line) {
    #if DEBUG
    let filename = (file as NSString).lastPathComponent
    print("[\(filename):\(line)] \(message)")
    #endif
}

// MARK: - API Response Models (Codable)

// Struktur für die gesamte API-Antwort für Bücher
struct BooksAPIResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [BookAPIModel]
}

// Struktur, die einem Buch-Eintrag der Readwise v2 API entspricht
// (Felder gemäss https://readwise.io/api_deets)
struct BookAPIModel: Codable, Identifiable {
    let id: Int // readwiseId
    let title: String
    let author: String?
    let category: String
    let source: String?
    let cover_image_url: String?
    let highlights_url: String? // Nicht direkt in BookPreview verwendet
    let source_url: String?    // Nicht direkt in BookPreview verwendet
    let last_highlight_at: String? // Wird als Date geparsed
    let num_highlights: Int
}

// MARK: - Highlights API Response Models

struct HighlightsAPIResponse: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [HighlightAPIModel]
}

// Struktur für ein Highlight von der Readwise API v2
// Felder basierend auf Annahmen und UI-Modell (HighlightItem)
struct HighlightAPIModel: Codable, Identifiable {
    let id: Int // readwiseId
    let text: String
    let note: String? // Mögliche Notizen
    let location: Int? // Einfache Location, muss ggf. interpretiert werden
    let location_type: String? // z.B. "page" oder "order"
    let highlighted_at: String? // Wird als Date geparsed
    let url: String? // URL zum Highlight
    let color: String? // Farbe des Highlights
    let updated: String? // Wann zuletzt aktualisiert
    let book_id: Int // Zugehörige Buch-ID
    let tags: [TagAPIModel]? // Tags (falls vorhanden)
}

// Struktur für Tags (falls benötigt)
struct TagAPIModel: Codable, Identifiable {
    let id: Int
    let name: String
}

/// Diese Klasse implementiert den ReadwiseAPIService nur für die reine API-Kommunikation
public class ReadwiseAPIService {
    public static let shared = ReadwiseAPIService()

    private let baseURL = "https://readwise.io/api/v2/"
    private let booksEndpoint = "books/"
    private let highlightsEndpoint = "highlights/"

    // Schlüssel für den API-Key in den UserDefaults
    private let apiKeyKey = "readwiseApiKey"

    // Certificate Pinning Delegate (wird als starke Referenz gehalten)
    private let pinningDelegate = CertificatePinningDelegate()

    // URLSession mit Certificate Pinning
    private lazy var pinnedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0
        configuration.timeoutIntervalForResource = 60.0
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration,
                         delegate: pinningDelegate,
                         delegateQueue: nil)
    }()

    // Date Formatter für ISO8601 mit optionalen Millisekunden
    private let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // Zweiter Formatter ohne Millisekunden als Fallback
    private let iso8601FormatterNoMillis: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    // Sicherstellen, dass der Initializer private ist, um Singleton zu erzwingen
    private init() {}
    
    // MARK: - API Key Management
    
    /// Speichert den API-Key sicher in der Keychain
    public func saveAPIKey(_ apiKey: String) throws {
        try KeychainHelper.standard.save(apiKey, service: "ReadwiseHighApp", account: apiKeyKey)
    }

    /// Holt den API-Key aus der Keychain
    public func getAPIKey() -> String {
        do {
            return try KeychainHelper.standard.read(service: "ReadwiseHighApp", account: apiKeyKey)
        } catch {
            return ""
        }
    }

    /// Löscht den API-Key aus der Keychain
    public func deleteAPIKey() throws {
        try KeychainHelper.standard.delete(service: "ReadwiseHighApp", account: apiKeyKey)
    }

    /// Prüft, ob ein API-Key vorhanden ist
    public func hasAPIKey() -> Bool {
        return !getAPIKey().isEmpty
    }

    // MARK: - API Call Methods (Nur die reinen API-Aufrufe bleiben hier)
    
    // Diese Methode führt den Netzwerkaufruf zum Abrufen von Büchern durch
    // Die Verarbeitung und das Mapping erfolgen jetzt im ReadwiseDataManager
    func fetchBooks(completion: @escaping (Result<BooksAPIResponse, ValidationError>) -> Void) {
        guard hasAPIKey() else {
            completion(.failure(.noKey))
            return
        }
        
        guard let url = URL(string: baseURL + booksEndpoint) else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.addValue("Token \(getAPIKey())", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        // Verwende gepinnte Session für sichere Kommunikation
        pinnedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.invalidKey))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(BooksAPIResponse.self, from: data)
                completion(.success(apiResponse))
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }

    // Diese Methode führt den Netzwerkaufruf zum Abrufen von Highlights durch
    // Die Verarbeitung und das Mapping erfolgen jetzt im ReadwiseDataManager
    func fetchHighlightsForBook(readwiseId: Int, completion: @escaping (Result<HighlightsAPIResponse, ValidationError>) -> Void) {
        guard hasAPIKey() else {
            completion(.failure(.noKey))
            return
        }
        
        guard var components = URLComponents(string: baseURL + highlightsEndpoint) else {
            completion(.failure(.invalidURL))
            return
        }
        components.queryItems = [URLQueryItem(name: "book_id", value: "\(readwiseId)")]

        guard let url = components.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Token \(getAPIKey())", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        // Verwende gepinnte Session für sichere Kommunikation
        pinnedSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 401 {
                    completion(.failure(.invalidKey))
                } else {
                    completion(.failure(.serverError(httpResponse.statusCode)))
                }
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            do {
                let apiResponse = try JSONDecoder().decode(HighlightsAPIResponse.self, from: data)
                completion(.success(apiResponse))
            } catch {
                completion(.failure(.invalidResponse))
            }
        }.resume()
    }
} 
