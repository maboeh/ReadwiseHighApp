import Foundation
import Combine
import SwiftUI // Für @Published etc.



// ViewModel für die BookDetailView
@MainActor // Stellt sicher, dass @Published Updates auf dem Main Thread passieren
class BookDetailViewModel: ObservableObject {
    let book: BookPreview // Das anzuzeigende Buch
    private let dataManager: ReadwiseDataManager

    // MARK: - Published Properties (State für die View)
    @Published var highlights: [HighlightItem] = []
    @Published var isLoadingHighlights: Bool = false
    @Published var highlightError: String? = nil
    @Published var copySuccessMessage: Bool = false // Zustand für Kopiervorgang

    // MARK: - Computed Properties
    var filteredHighlights: [HighlightItem] {
        // Suchlogik (falls wir sie später wieder hinzufügen wollen)
        // Hier vorerst alle Highlights zurückgeben
        return highlights
    }

    var allHighlightsText: String {
        let highlightsToCopy = filteredHighlights
        return highlightsToCopy.map { highlight in
            var detailText = "\"\(highlight.text)\""
            if !highlight.chapterTitle.isEmpty {
                detailText += "\nKapitel: \(highlight.chapterTitle)"
            }
            return detailText
        }.joined(separator: "\n\n----------\n\n")
    }

    // MARK: - Initializer
    init(book: BookPreview, dataManager: ReadwiseDataManager) {
        self.book = book
        self.dataManager = dataManager
        print("✨ BookDetailViewModel initialized for book: '\(book.title)' (ID: \(book.readwiseId ?? -1))")
        
    }

    // MARK: - Public Methods (Actions for the View)

    func loadHighlights() {
        print("-> [ViewModel DEBUG] loadHighlights aufgerufen für Buch-ID: \(book.readwiseId ?? -1).")
        guard let bookId = book.readwiseId else {
            print("<- [ViewModel DEBUG] loadHighlights - Keine gültige Buch-ID.")
            self.highlightError = "Buch-ID nicht gefunden."
            return
        }

        // Vermeide erneutes Laden, nur wenn bereits geladen wird
        if isLoadingHighlights {
             print("<- [ViewModel DEBUG] loadHighlights - Lädt bereits.")
             return
        }

        print("   [ViewModel DEBUG] Starte Ladevorgang für Highlights...")
        isLoadingHighlights = true
        highlights = []
        highlightError = nil

        
        dataManager.loadHighlights(for: bookId) { [weak self] (result: Result<[HighlightItem], Error>) in
            
                 guard let self = self else { return }
                 print("<- [ViewModel DEBUG] loadHighlights beendet (DataManager hat geliefert).")
                 print("   [ViewModel DEBUG] DataManager Ergebnis: \(result)")
                 self.isLoadingHighlights = false
                 switch result {
                 case .success(let fetchedHighlights):
                     print("✅ [ViewModel] Highlights geladen: \(fetchedHighlights.count) Stück")
                     self.highlights = fetchedHighlights
                     self.highlightError = nil
                 case .failure(let error):
                     print("❌ [ViewModel] Fehler beim Laden der Highlights: \(error)")
                     self.highlightError = "Fehler: \(error.localizedDescription)"
                 }
            // }
        }
    }

    func copyAllHighlightsToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = allHighlightsText
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allHighlightsText, forType: .string)
        #endif

        copySuccessMessage = true
        // Verwende Task.sleep für asynchrone Wartezeit in @MainActor Context
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) 
             await MainActor.run {
                self.copySuccessMessage = false
            }
        }
    }
} 