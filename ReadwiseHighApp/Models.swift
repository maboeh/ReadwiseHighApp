import Foundation
import SwiftUI // Nötig für Color, etc. falls in Zukunft verwendet

// MARK: - Modelltypen und Enums

// LoadingState-Enum für die App
public enum LoadingState: Equatable {
    case idle
    case loadingBooks
    case loadingHighlights
    case error(String)
    
    public var isLoading: Bool {
        switch self {
        case .idle, .error:
            return false
        default:
            return true
        }
    }
    
    public static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loadingBooks, .loadingBooks),
             (.loadingHighlights, .loadingHighlights):
            return true
        case (.error(let lhsMsg), .error(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// ValidationError-Enum für die App
public enum ValidationError: Error, Equatable {
    case noKey
    case invalidKey
    case networkError(String)
    case invalidResponse
    case serverError(Int)
    case invalidURL
    case noData
    
    public static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.noKey, .noKey), (.invalidKey, .invalidKey), (.invalidResponse, .invalidResponse),
             (.invalidURL, .invalidURL), (.noData, .noData):
            return true
        case (.serverError(let lCode), .serverError(let rCode)):
            return lCode == rCode
        case (.networkError(let lMsg), .networkError(let rMsg)):
            return lMsg == rMsg
        default:
            return false
        }
    }
}

// Buchvorschau-Modell für die UI
public struct BookPreview: Identifiable, Codable, Hashable {
    public var id: Int
    public var title: String = ""
    public var author: String = ""
    public var category: String = ""
    public var coverImageURL: URL? = nil
    public var readwiseId: Int? = nil // ID von Readwise
    public var highlightIds: [UUID] = [] // Verweis auf Highlight-IDs (optional)
    public var numHighlights: Int = 0
    public var lastHighlightAt: Date? = nil
    
    public init(title: String = "", author: String = "", category: String = "", coverImageURL: URL? = nil, readwiseId: Int? = nil, highlightIds: [UUID] = [], numHighlights: Int = 0, lastHighlightAt: Date? = nil) {
        self.readwiseId = readwiseId
        self.id = readwiseId ?? -1 // Verwende readwiseId als stabile ID, -1 als Fallback falls nil
        self.title = title
        self.author = author
        self.category = category
        self.coverImageURL = coverImageURL
        self.highlightIds = highlightIds
        self.numHighlights = numHighlights
        self.lastHighlightAt = lastHighlightAt
    }
}

// Highlight-Modell für die UI
public struct HighlightItem: Identifiable, Codable, Hashable {
    public var id: UUID = UUID() // UI-interne ID
    public var text: String = ""
    public var page: Int = 0
    public var chapter: Int = 0
    public var chapterTitle: String = ""
    public var date: Date = Date() // Vom API-String geparsed
    public var readwiseId: Int? = nil // ID von Readwise
    public var bookId: Int? = nil // Verweis auf Buch-ID von Readwise
}

// MARK: - Notifications

extension Notification.Name {
    /// Wird gesendet, wenn die API-Key-Ansicht gezeigt werden soll (z.B. wegen ungültigem Schlüssel).
    static let showAPIKeyViewNotification = Notification.Name("showAPIKeyViewNotification")
} 