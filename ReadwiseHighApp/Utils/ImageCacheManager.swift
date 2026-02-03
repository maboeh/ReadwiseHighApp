import Combine
import CryptoKit
import Foundation
import SwiftUI

/// Hilfklasse für die URLSession-Verwaltung
class ImageSessionManager {
    static let shared = ImageSessionManager()
    
    let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        config.waitsForConnectivity = true
        config.httpMaximumConnectionsPerHost = 8
        
        let headers = ["User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15"]
        config.httpAdditionalHeaders = headers
        
        session = URLSession(configuration: config)
    }
}

/// Fehlertypen für den ImageCacheManager
enum ImageCacheError: Error {
    case invalidURL
    case networkError(Error)
    case noData
    case imageConversionFailed
    case fileSystemError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Die URL ist ungültig."
        case .networkError(let error):
            return "Netzwerkfehler: \(error.localizedDescription)"
        case .noData:
            return "Keine Daten erhalten."
        case .imageConversionFailed:
            return "Das Bild konnte nicht konvertiert werden."
        case .fileSystemError(let error):
            return "Dateisystemfehler: \(error.localizedDescription)"
        }
    }
}

// MARK: - Hilfstypaliase

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

/// Manager für den Bildcache (Memory und Disk)
class ImageCacheManager {
    // Singleton-Instanz
    static let shared = ImageCacheManager()
    
    // MARK: - Cache-Eigenschaften
    
    /// In-Memory-Cache für schnellen Zugriff
    private let memoryCache = NSCache<NSString, AnyObject>()
    
    /// Verzeichnis für den Disk-Cache
    private let diskCacheDirectory: URL
    
    /// Die maximale Anzahl von Tagen, die ein Bild im Cache bleiben soll
    private let maxCacheDays: Int = 30
    
    /// Die URLSession für Netzwerkanfragen
    private var session: URLSession {
        return ImageSessionManager.shared.session
    }
    
    // MARK: - Initialisierung
    
    private init() {
        // Konfigurieren des Memory-Cache
        memoryCache.countLimit = 100 // Maximal 100 Bilder im Speicher

        // Pfad zum Cache-Verzeichnis ermitteln
        let fileManager = FileManager.default
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")

        // Cache-Verzeichnis erstellen mit File Protection
        // NSFileProtectionComplete: Dateien nur zugänglich wenn Gerät entsperrt
        do {
            try fileManager.createDirectory(at: diskCacheDirectory,
                                          withIntermediateDirectories: true,
                                          attributes: [.protectionKey: FileProtectionType.complete])
        } catch {
            #if DEBUG
            print("⚠️ Fehler beim Erstellen des Cache-Verzeichnisses: \(error)")
            #endif
        }

        // Alte Cache-Dateien im Hintergrund löschen
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.cleanOldCacheFiles()
        }
    }
    
    // MARK: - Öffentliche Methoden
    
    /// Generiert einen eindeutigen Schlüssel für eine URL
    func cacheKey(for url: URL) -> String {
        // SHA256-Hash der URL für eindeutigen, dateisystemsicheren Schlüssel
        let inputData = Data(url.absoluteString.utf8)
        if #available(iOS 13.0, macOS 10.15, *) {
            let hashed = SHA256.hash(data: inputData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } else {
            // Fallback für ältere Systeme
            return url.absoluteString
                .replacingOccurrences(of: "://", with: "_")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: ".", with: "_")
                .replacingOccurrences(of: ":", with: "_")
        }
    }
    
    /// Lädt ein Bild von einer URL und speichert es im Cache
    func loadImage(from url: URL, completion: @escaping (Result<PlatformImage, Error>) -> Void) {
        let cacheKey = self.cacheKey(for: url)
        
        // 1. Prüfen, ob das Bild im Memory-Cache ist
        if let cachedImage = getImageFromMemoryCache(forKey: cacheKey) {
            completion(.success(cachedImage))
            return
        }
        
        // 2. Prüfen, ob das Bild im Disk-Cache ist
        if let diskCachedImage = getImageFromDiskCache(forKey: cacheKey) {
            // In den Memory-Cache laden für schnelleren Zugriff
            saveImageToMemoryCache(diskCachedImage, forKey: cacheKey)
            completion(.success(diskCachedImage))
            return
        }
        
        // 3. Bild aus dem Netzwerk laden
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(.failure(ImageCacheError.networkError(error)))
                return
            }
            
            guard let data = data else {
                completion(.failure(ImageCacheError.noData))
                return
            }
            
            #if os(macOS)
            guard let image = NSImage(data: data) else {
                completion(.failure(ImageCacheError.imageConversionFailed))
                return
            }
            #else
            guard let image = UIImage(data: data) else {
                completion(.failure(ImageCacheError.imageConversionFailed))
                return
            }
            #endif
            
            // Bild in beiden Caches speichern
            self.saveImageToMemoryCache(image, forKey: cacheKey)
            self.saveImageToDiskCache(image, forKey: cacheKey)
            
            completion(.success(image))
        }
        
        task.resume()
    }
    
    /// Holt ein Bild aus dem Memory-Cache
    func getImageFromMemoryCache(forKey key: String) -> PlatformImage? {
        return memoryCache.object(forKey: key as NSString) as? PlatformImage
    }
    
    /// Speichert ein Bild im Memory-Cache
    func saveImageToMemoryCache(_ image: PlatformImage, forKey key: String) {
        memoryCache.setObject(image, forKey: key as NSString)
    }
    
    /// Holt ein Bild aus dem Disk-Cache
    func getImageFromDiskCache(forKey key: String) -> PlatformImage? {
        let fileURL = diskCacheDirectory.appendingPathComponent("\(key).png")
        
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }
    
    /// Speichert ein Bild im Disk-Cache
    func saveImageToDiskCache(_ image: PlatformImage, forKey key: String) {
        let fileURL = diskCacheDirectory.appendingPathComponent("\(key).png")
        
        #if os(macOS)
        // Für macOS: NSImage in PNG-Daten umwandeln
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            #if DEBUG
            print("⚠️ Fehler beim Konvertieren des NSImage in PNG-Daten")
            #endif
            return
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            #if DEBUG
            print("⚠️ Fehler beim Konvertieren des NSImage in PNG-Daten")
            #endif
            return
        }
        #else
        // Für iOS: UIImage in PNG-Daten umwandeln
        guard let pngData = image.pngData() else {
            #if DEBUG
            print("⚠️ Fehler beim Konvertieren des UIImage in PNG-Daten")
            #endif
            return
        }
        #endif

        do {
            // Schreibe Daten mit File Protection
            try pngData.write(to: fileURL, options: [.completeFileProtection])
        } catch {
            #if DEBUG
            print("⚠️ Fehler beim Speichern des Bildes auf der Festplatte: \(error)")
            #endif
        }
    }
    
    /// Löscht alle Bilder aus dem Cache
    func clearCache() {
        // Memory-Cache leeren
        memoryCache.removeAllObjects()
        
        // Disk-Cache leeren
        let fileManager = FileManager.default
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: diskCacheDirectory, 
                                                             includingPropertiesForKeys: nil, 
                                                             options: [])
            for fileURL in fileURLs {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            #if DEBUG
            print("⚠️ Fehler beim Leeren des Disk-Cache: \(error)")
            #endif
        }
    }

    // MARK: - Private Hilfsmethoden

    /// Löscht Cache-Dateien, die älter als maxCacheDays sind
    private func cleanOldCacheFiles() {
        let fileManager = FileManager.default
        let currentDate = Date()

        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: diskCacheDirectory,
                                                             includingPropertiesForKeys: [.creationDateKey],
                                                             options: [])

            for fileURL in fileURLs {
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attributes[.creationDate] as? Date {

                    let ageInDays = Calendar.current.dateComponents([.day], from: creationDate, to: currentDate).day ?? 0

                    if ageInDays > maxCacheDays {
                        try? fileManager.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            #if DEBUG
            print("⚠️ Fehler beim Bereinigen alter Cache-Dateien: \(error)")
            #endif
        }
    }
}
