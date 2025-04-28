import Foundation
import Combine
import SwiftUI 

// Data Manager als primäre Schnittstelle für die UI
public class ReadwiseDataManager: ObservableObject {
    public static let shared = ReadwiseDataManager() // Singleton bleibt für einfachen Zugriff

    @Published public var loadingState: LoadingState = .idle
    @Published public var lastUpdate: Date?
    @Published public var fullyLoadedBooks: [BookPreview] = []
    @Published public var shouldShowAPIKeyView: Bool = false

    // API Service wird injiziert
    private let apiService: ReadwiseAPIService

    // Dependency Injection im Initializer
    private init(apiService: ReadwiseAPIService = .shared) {
        self.apiService = apiService
        updateAPIKeyViewState() // Initialen Status prüfen
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        // Verwende die zentral definierte Notification.Name
        NotificationCenter.default.addObserver(forName: .showAPIKeyViewNotification, object: nil, queue: .main) { [weak self] _ in
            if !(self?.shouldShowAPIKeyView ?? false) {
                self?.shouldShowAPIKeyView = true
            }
        }
    }

    /// Aktualisiert den Status, ob die API-Key-Ansicht gezeigt werden soll
    public func updateAPIKeyViewState() {
        self.shouldShowAPIKeyView = !apiService.hasAPIKey()
    }

    // MARK: - Data Loading Methods

    /// Lädt die Bücherliste
    public func loadBooks() {
        // Verhindere parallele Ladevorgänge
        guard loadingState != .loadingBooks && loadingState != .loadingHighlights else {
            print("ℹ️ Ladevorgang (Bücher) läuft bereits.")
            return
        }

        print("🚀 Starte Ladevorgang für Bücher...")
        loadingState = .loadingBooks
        
        apiService.fetchBooks { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // Ladezustand zurücksetzen
                self.loadingState = .idle
                switch result {
                case .success(let apiResponse):
                    // Daten mappen und aktualisieren
                    let books = self.mapBooks(from: apiResponse)
                    self.fullyLoadedBooks = books
                    self.lastUpdate = Date()
                case .failure(let error):
                    print("❌ Fehler beim Laden der Bücher: \(error)")
                    if let validationError = error as? ValidationError,
                       (validationError == .noKey || validationError == .invalidKey) {
                        // Zeige API-Key-Eingabe
                        self.shouldShowAPIKeyView = true
                    } else {
                        // Anderen Fehler anzeigen
                        self.loadingState = .error(error.localizedDescription)
                    }
                }
            }
        }
    }

    /// Lädt die Highlights für ein bestimmtes Buch
    /// Gibt das Ergebnis über eine Completion zurück, damit die DetailView es verarbeiten kann
    public func loadHighlights(for bookId: Int, completion: @escaping (Result<[HighlightItem], Error>) -> Void) {
        print("🚀 Starte Ladevorgang für Highlights (Buch-ID: \(bookId))...")

        // Prüfe API Key direkt hier
        guard apiService.hasAPIKey() else {
            let error = ValidationError.noKey
            print("❌ Fehler beim Laden der Highlights: \(error)")
            handleAPIError(error) // Auch hier den Fehlerstatus setzen
            completion(.failure(error)) // Completion mit spezifischem Fehler aufrufen
            return
        }

        // Rufe die fetchHighlightsForBook-Methode des *injizierten* API-Service auf
        // Der API-Service liefert jetzt HighlightsAPIResponse
        apiService.fetchHighlightsForBook(readwiseId: bookId) { [weak self] result in
            DispatchQueue.main.async {
                 guard let self = self else { return }

                 // Verarbeite das Ergebnis (Success oder Failure)
                 switch result {
                 case .success(let apiResponse):
                     // Mappe die API-Response zu HighlightItem-Objekten
                     let highlights = self.mapHighlights(from: apiResponse)
                     print("✅ \(highlights.count) Highlights für Buch \(bookId) erfolgreich geladen.")
                     completion(.success(highlights))
                 case .failure(let error):
                     print("❌ Fehler beim Laden der Highlights für Buch \(bookId): \(error)")
                     self.handleAPIError(error) // Fehler zentral im DataManager behandeln
                     completion(.failure(error)) // Completion mit Fehler aufrufen
                 }
            }
        }
    }

    // MARK: - Mapping Helpers

    /// Mappt eine BooksAPIResponse zu einem Array von BookPreview-Objekten
    private func mapBooks(from apiResponse: BooksAPIResponse) -> [BookPreview] {
        let iso8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        let iso8601FormatterNoMillis: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()

        return apiResponse.results.map { apiBook -> BookPreview in
            var highlightDate: Date? = nil
            if let dateString = apiBook.last_highlight_at {
                if let date = iso8601Formatter.date(from: dateString) {
                    highlightDate = date
                } else if let date = iso8601FormatterNoMillis.date(from: dateString) {
                    highlightDate = date
                }
            }

            // Verwende den Initializer von BookPreview (aus Models.swift)
            return BookPreview(
                title: apiBook.title,
                author: apiBook.author ?? "Unbekannt",
                category: apiBook.category,
                coverImageURL: URL(string: apiBook.cover_image_url ?? ""),
                readwiseId: apiBook.id,
                numHighlights: apiBook.num_highlights,
                lastHighlightAt: highlightDate
            )
        }
    }

    /// Mappt eine HighlightsAPIResponse zu einem Array von HighlightItem-Objekten
    private func mapHighlights(from apiResponse: HighlightsAPIResponse) -> [HighlightItem] {
        let iso8601Formatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()
        let iso8601FormatterNoMillis: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            return formatter
        }()

        return apiResponse.results.map { apiHighlight -> HighlightItem in
            var highlightDate: Date = Date()
            if let dateString = apiHighlight.highlighted_at {
                if let date = iso8601Formatter.date(from: dateString) {
                    highlightDate = date
                } else if let date = iso8601FormatterNoMillis.date(from: dateString) {
                    highlightDate = date
                }
            }

            var pageNum = 0
            if apiHighlight.location_type == "page", let loc = apiHighlight.location {
                pageNum = loc
            }

            // Verwende den Initializer von HighlightItem (aus Models.swift)
            return HighlightItem(
                id: UUID(),
                text: apiHighlight.text,
                page: pageNum,
                chapter: 0,
                chapterTitle: "",
                date: highlightDate,
                readwiseId: apiHighlight.id,
                bookId: apiHighlight.book_id
            )
        }
    }


    /// Hilfsfunktion zur Behandlung von API-Fehlern und Aktualisierung des UI-Status
    private func handleAPIError(_ error: Error) {
        // Setze den globalen Ladezustand auf Fehler
        if let validationError = error as? ValidationError {
            // Erstelle eine benutzerfreundlichere Nachricht basierend auf dem Fehler
            let errorMessage: String
            switch validationError {
            case .noKey:
                errorMessage = "Kein API-Schlüssel hinterlegt."
            case .invalidKey:
                errorMessage = "Der API-Schlüssel ist ungültig."
            case .networkError(let detail):
                errorMessage = "Netzwerkfehler: \(detail)"
            case .invalidResponse:
                errorMessage = "Ungültige Serverantwort."
            case .serverError(let code):
                errorMessage = "Serverfehler (Code: \(code))."
            case .invalidURL:
                errorMessage = "Interne Fehlkonfiguration (URL)."
            case .noData:
                errorMessage = "Keine Daten empfangen."
            }
            self.loadingState = .error(errorMessage)

            // Spezifische UI-Reaktion: APIKeyView öffnen
            if validationError == .noKey || validationError == .invalidKey {
                self.shouldShowAPIKeyView = true
            }
        } else {
            // Fallback für allgemeine Fehler
            self.loadingState = .error("Ein unerwarteter Fehler ist aufgetreten: \(error.localizedDescription)")
        }
    }

    /// Bequeme Funktion, die oft von der UI aufgerufen wird (z.B. beim Start oder Refresh)
    /// Lädt nur die Bücherliste. Highlights werden bei Bedarf geladen.
    public func refreshData() {
        loadBooks()
        // Highlights werden bei Bedarf von der DetailView über loadHighlights geladen
    }
}
