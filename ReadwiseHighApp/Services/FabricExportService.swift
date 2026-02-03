import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Fabric Export Service

/// Service zum Exportieren von Highlights nach Fabric.so
/// Da Fabric keine öffentliche API hat, nutzen wir den Cloud-Sync-Ansatz:
/// - Highlights werden als Markdown-Dateien exportiert
/// - Dateien werden in einem Sync-Ordner gespeichert (iCloud, Dropbox, etc.)
/// - Fabric synchronisiert diesen Ordner automatisch
/// - Bei Updates wird dieselbe Datei überschrieben (keine Duplikate)
public class FabricExportService {

    // MARK: - Singleton

    public static let shared = FabricExportService()

    // MARK: - Constants

    private let exportFolderKey = "fabricExportFolder"
    private let exportedBooksKey = "fabricExportedBooks"
    private let defaultFolderName = "ReadwiseHighlights"

    // MARK: - Properties

    /// Das konfigurierte Export-Verzeichnis
    private var exportDirectory: URL? {
        get {
            guard let bookmarkData = UserDefaults.standard.data(forKey: exportFolderKey) else {
                return defaultExportDirectory
            }

            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: bookmarkData,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale)

                if isStale {
                    // Bookmark ist veraltet, neuen erstellen
                    #if DEBUG
                    print("⚠️ Bookmark ist veraltet, verwende Standard-Verzeichnis")
                    #endif
                    return defaultExportDirectory
                }

                return url
            } catch {
                #if DEBUG
                print("⚠️ Fehler beim Auflösen des Bookmarks: \(error)")
                #endif
                return defaultExportDirectory
            }
        }
    }

    /// Standard-Export-Verzeichnis (Documents/ReadwiseHighlights)
    private var defaultExportDirectory: URL? {
        let fileManager = FileManager.default
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let exportDir = documentsDir.appendingPathComponent(defaultFolderName)

        // Verzeichnis erstellen falls nicht vorhanden
        if !fileManager.fileExists(atPath: exportDir.path) {
            do {
                try fileManager.createDirectory(at: exportDir,
                                              withIntermediateDirectories: true,
                                              attributes: [.protectionKey: FileProtectionType.complete])
            } catch {
                #if DEBUG
                print("⚠️ Fehler beim Erstellen des Export-Verzeichnisses: \(error)")
                #endif
                return nil
            }
        }

        return exportDir
    }

    /// Dictionary mit exportierten Büchern und ihren letzten Export-Zeitstempeln
    private var exportedBooks: [Int: Date] {
        get {
            guard let data = UserDefaults.standard.data(forKey: exportedBooksKey),
                  let dict = try? JSONDecoder().decode([Int: Date].self, from: data) else {
                return [:]
            }
            return dict
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: exportedBooksKey)
            }
        }
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Exportiert alle Highlights eines Buches als Markdown-Datei
    /// - Parameters:
    ///   - book: Das Buch dessen Highlights exportiert werden sollen
    ///   - highlights: Die Highlights des Buches
    ///   - completion: Callback mit Ergebnis (Erfolg mit Datei-URL oder Fehler)
    public func exportHighlights(for book: BookPreview,
                                highlights: [HighlightItem],
                                completion: @escaping (Result<URL, FabricExportError>) -> Void) {

        guard let exportDir = exportDirectory else {
            completion(.failure(.noExportDirectory))
            return
        }

        guard !highlights.isEmpty else {
            completion(.failure(.noHighlights))
            return
        }

        // Dateiname basierend auf Buchtitel (sanitized)
        let safeTitle = sanitizeFilename(book.title)
        let filename = "\(safeTitle).md"
        let fileURL = exportDir.appendingPathComponent(filename)

        // Markdown-Inhalt generieren
        let markdownContent = generateMarkdown(for: book, highlights: highlights)

        // In Datei schreiben (überschreibt existierende Datei = Update statt Duplikat)
        do {
            // Security-scoped access starten falls nötig
            let accessGranted = exportDir.startAccessingSecurityScopedResource()
            defer {
                if accessGranted {
                    exportDir.stopAccessingSecurityScopedResource()
                }
            }

            try markdownContent.write(to: fileURL, atomically: true, encoding: .utf8)

            // File Protection setzen
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )

            // Export-Zeitstempel speichern
            if let bookId = book.readwiseId {
                var exported = exportedBooks
                exported[bookId] = Date()
                exportedBooks = exported
            }

            #if DEBUG
            print("✅ Highlights exportiert nach: \(fileURL.path)")
            #endif

            completion(.success(fileURL))

        } catch {
            #if DEBUG
            print("❌ Fehler beim Exportieren: \(error)")
            #endif
            completion(.failure(.writeError(error.localizedDescription)))
        }
    }

    /// Prüft ob ein Buch bereits exportiert wurde
    /// - Parameter bookId: Die Readwise-ID des Buches
    /// - Returns: Das Datum des letzten Exports oder nil
    public func lastExportDate(for bookId: Int) -> Date? {
        return exportedBooks[bookId]
    }

    /// Prüft ob das Export-Verzeichnis konfiguriert und zugänglich ist
    public var isConfigured: Bool {
        guard let dir = exportDirectory else { return false }
        return FileManager.default.fileExists(atPath: dir.path)
    }

    /// Gibt den Pfad zum Export-Verzeichnis zurück
    public var exportPath: String? {
        return exportDirectory?.path
    }

    /// Setzt das Export-Verzeichnis
    /// - Parameter url: Die URL des neuen Export-Verzeichnisses
    public func setExportDirectory(_ url: URL) throws {
        // Bookmark erstellen für persistenten Zugriff
        let bookmarkData = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        UserDefaults.standard.set(bookmarkData, forKey: exportFolderKey)

        #if DEBUG
        print("✅ Export-Verzeichnis gesetzt: \(url.path)")
        #endif
    }

    /// Setzt das Export-Verzeichnis auf den Standard zurück
    public func resetExportDirectory() {
        UserDefaults.standard.removeObject(forKey: exportFolderKey)
    }

    // MARK: - Private Methods

    /// Generiert Markdown-Inhalt für ein Buch mit seinen Highlights
    private func generateMarkdown(for book: BookPreview, highlights: [HighlightItem]) -> String {
        var md = ""

        // Header
        md += "# \(book.title)\n\n"

        // Metadaten
        md += "**Autor:** \(book.author)\n"
        md += "**Kategorie:** \(book.category)\n"
        md += "**Anzahl Highlights:** \(highlights.count)\n"

        if let lastHighlight = book.lastHighlightAt {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            formatter.locale = Locale(identifier: "de_DE")
            md += "**Letztes Highlight:** \(formatter.string(from: lastHighlight))\n"
        }

        // Export-Zeitstempel
        let exportFormatter = DateFormatter()
        exportFormatter.dateStyle = .medium
        exportFormatter.timeStyle = .short
        exportFormatter.locale = Locale(identifier: "de_DE")
        md += "**Exportiert:** \(exportFormatter.string(from: Date()))\n"
        md += "**Quelle:** ReadwiseHighApp\n"

        md += "\n---\n\n"

        // Highlights
        md += "## Highlights\n\n"

        // Sortiere Highlights nach Seite/Datum
        let sortedHighlights = highlights.sorted { h1, h2 in
            if h1.page != h2.page {
                return h1.page < h2.page
            }
            return h1.date < h2.date
        }

        for (index, highlight) in sortedHighlights.enumerated() {
            // Highlight-Text als Zitat
            md += "> \(highlight.text)\n\n"

            // Metadaten
            var meta: [String] = []

            if highlight.page > 0 {
                meta.append("Seite \(highlight.page)")
            }

            if !highlight.chapterTitle.isEmpty {
                meta.append("Kapitel: \(highlight.chapterTitle)")
            } else if highlight.chapter > 0 {
                meta.append("Kapitel \(highlight.chapter)")
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.locale = Locale(identifier: "de_DE")
            meta.append(dateFormatter.string(from: highlight.date))

            if !meta.isEmpty {
                md += "*— \(meta.joined(separator: " · "))*\n\n"
            }

            // Trennlinie zwischen Highlights (außer beim letzten)
            if index < sortedHighlights.count - 1 {
                md += "---\n\n"
            }
        }

        // Footer
        md += "\n---\n\n"
        md += "*Exportiert aus Readwise via ReadwiseHighApp*\n"

        return md
    }

    /// Bereinigt einen Dateinamen von ungültigen Zeichen
    private func sanitizeFilename(_ filename: String) -> String {
        // Ungültige Zeichen für Dateinamen entfernen
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        var sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "_")

        // Mehrfache Unterstriche reduzieren
        while sanitized.contains("__") {
            sanitized = sanitized.replacingOccurrences(of: "__", with: "_")
        }

        // Führende/trailing Unterstriche entfernen
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_ "))

        // Maximale Länge begrenzen (255 Zeichen minus Erweiterung)
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }

        // Falls leer, Fallback verwenden
        if sanitized.isEmpty {
            sanitized = "Highlights"
        }

        return sanitized
    }
}

// MARK: - Error Types

/// Fehler beim Fabric-Export
public enum FabricExportError: Error, LocalizedError {
    case noExportDirectory
    case noHighlights
    case writeError(String)
    case accessDenied

    public var errorDescription: String? {
        switch self {
        case .noExportDirectory:
            return "Kein Export-Verzeichnis konfiguriert. Bitte wähle einen Ordner in den Einstellungen."
        case .noHighlights:
            return "Keine Highlights zum Exportieren vorhanden."
        case .writeError(let message):
            return "Fehler beim Schreiben der Datei: \(message)"
        case .accessDenied:
            return "Zugriff auf das Export-Verzeichnis verweigert."
        }
    }
}

// MARK: - Export Result

/// Ergebnis eines Exports für die UI
public struct FabricExportResult {
    public let fileURL: URL
    public let filename: String
    public let highlightCount: Int
    public let isUpdate: Bool

    public var message: String {
        if isUpdate {
            return "\(highlightCount) Highlights aktualisiert in '\(filename)'"
        } else {
            return "\(highlightCount) Highlights exportiert nach '\(filename)'"
        }
    }
}
