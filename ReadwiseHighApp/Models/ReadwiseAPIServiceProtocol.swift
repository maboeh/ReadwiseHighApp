import Foundation
import Combine

// Protokoll für den API-Service mit typischem Service-Definition
public protocol ReadwiseAPIServiceProtocol: AnyObject {
    /// Holt Bücher und ruft den Completion-Handler mit dem Ergebnis auf
    func fetchBooks(withApiKey apiKey: String, completion: @escaping (Result<[BookPreview], Error>) -> Void)
    
    /// Holt Highlights für ein bestimmtes Buch und ruft den Completion-Handler mit dem Ergebnis auf
    func fetchHighlights(forBookId bookId: Int, withApiKey apiKey: String, completion: @escaping (Result<[HighlightItem], Error>) -> Void)
} 
