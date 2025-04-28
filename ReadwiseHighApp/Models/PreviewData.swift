import Foundation
import SwiftUI

public struct LocalBookPreview {
    public var id: UUID
    public var title: String
    public var author: String
    public var category: String
    public var coverImageURL: URL?
    public var readwiseId: Int?
    public var highlightIds: [UUID]
    public var numHighlights: Int
    public var lastHighlightAt: Date?
    
    public init(id: UUID = UUID(), 
                title: String, 
                author: String, 
                category: String, 
                coverImageURL: URL? = nil, 
                readwiseId: Int? = nil, 
                highlightIds: [UUID] = [], 
                numHighlights: Int = 0, 
                lastHighlightAt: Date? = nil) {
        self.id = id
        self.title = title
        self.author = author
        self.category = category
        self.coverImageURL = coverImageURL
        self.readwiseId = readwiseId
        self.highlightIds = highlightIds
        self.numHighlights = numHighlights
        self.lastHighlightAt = lastHighlightAt
    }
}

public struct LocalHighlightItem {
    public var id: UUID
    public var text: String
    public var page: Int
    public var chapter: Int
    public var chapterTitle: String
    public var date: Date
    public var readwiseId: Int?
    public var bookId: Int?
    
    public init(id: UUID = UUID(), 
                text: String, 
                page: Int, 
                chapter: Int, 
                chapterTitle: String, 
                date: Date, 
                readwiseId: Int? = nil, 
                bookId: Int? = nil) {
        self.id = id
        self.text = text
        self.page = page
        self.chapter = chapter
        self.chapterTitle = chapterTitle
        self.date = date
        self.readwiseId = readwiseId
        self.bookId = bookId
    }
}

public struct PreviewData {
    
    public static let sampleBooks: [LocalBookPreview] = [
        LocalBookPreview(
            id: UUID(),
            title: "Die Kunst des klaren Denkens",
            author: "Rolf Dobelli",
            category: "Buch",
            coverImageURL: URL(string: "https://m.media-amazon.com/images/I/41Xr8fXVstL._SL500_.jpg"),
            readwiseId: 1,
            highlightIds: [UUID(), UUID(), UUID()],
            numHighlights: 12,
            lastHighlightAt: Date().addingTimeInterval(-86400 * 10)
        ),
        LocalBookPreview(
            id: UUID(),
            title: "Atomic Habits",
            author: "James Clear",
            category: "Buch",
            coverImageURL: URL(string: "https://m.media-amazon.com/images/I/51-nXsSRfZL._SL500_.jpg"),
            readwiseId: 2,
            highlightIds: [UUID()],
            numHighlights: 15,
            lastHighlightAt: Date().addingTimeInterval(-86400 * 5)
        ),
        LocalBookPreview(
            id: UUID(),
            title: "Wie Apps unser Leben verändern",
            author: "Max Mustermann",
            category: "Artikel",
            coverImageURL: URL(string: "https://example.com/article1.jpg"),
            readwiseId: 3,
            highlightIds: [UUID(), UUID()],
            numHighlights: 5,
            lastHighlightAt: Date().addingTimeInterval(-86400 * 2)
        ),
        LocalBookPreview(
            id: UUID(),
            title: "Die Zukunft der KI",
            author: "Erika Musterfrau",
            category: "Podcast",
            coverImageURL: URL(string: "https://example.com/podcast1.jpg"),
            readwiseId: 4,
            highlightIds: [UUID()],
            numHighlights: 3,
            lastHighlightAt: Date().addingTimeInterval(-86400 * 7)
        ),
        LocalBookPreview(
            id: UUID(),
            title: "Swift UI für Anfänger",
            author: "Felix Schmidt",
            category: "PDF/Dokument",
            coverImageURL: URL(string: "https://example.com/pdf1.jpg"),
            readwiseId: 5,
            highlightIds: [UUID(), UUID(), UUID()],
            numHighlights: 8,
            lastHighlightAt: Date().addingTimeInterval(-86400 * 1)
        )
    ]

    
    public static let sampleHighlightsBook1: [LocalHighlightItem] = [
        LocalHighlightItem(
            id: UUID(),
            text: "Wir neigen dazu, die Wahrscheinlichkeit von Ereignissen zu überschätzen, die uns leicht einfallen.",
            page: 23,
            chapter: 1,
            chapterTitle: "Verfügbarkeitsheuristik",
            date: Date().addingTimeInterval(-86400 * 10),
            readwiseId: 101,
            bookId: 1
        ),
        LocalHighlightItem(
            id: UUID(),
            text: "Der Bestätigungsfehler ist die Tendenz, Informationen so zu interpretieren, dass sie unsere bestehenden Theorien bestätigen.",
            page: 45,
            chapter: 2,
            chapterTitle: "Bestätigungsfehler",
            date: Date().addingTimeInterval(-86400 * 8),
            readwiseId: 102,
            bookId: 1
        ),
        LocalHighlightItem(
            id: UUID(),
            text: "Je mehr Optionen wir haben, desto unzufriedener werden wir mit unserer Wahl.",
            page: 78,
            chapter: 3,
            chapterTitle: "Paradox der Wahl",
            date: Date().addingTimeInterval(-86400 * 5),
            readwiseId: 103,
            bookId: 1
        )
    ]

   
    public static let sampleHighlightsBook2: [LocalHighlightItem] = [
        LocalHighlightItem(
            id: UUID(),
            text: "Kleine Gewohnheiten summieren sich zu großen Ergebnissen.",
            page: 15,
            chapter: 1,
            chapterTitle: "Die überraschende Macht kleiner Gewohnheiten",
            date: Date().addingTimeInterval(-86400 * 12),
            readwiseId: 201,
            bookId: 2
        ),
        LocalHighlightItem(
            id: UUID(),
            text: "Vergessen Sie Ziele, konzentrieren Sie sich auf Systeme.",
            page: 27,
            chapter: 1,
            chapterTitle: "Die überraschende Macht kleiner Gewohnheiten",
            date: Date().addingTimeInterval(-86400 * 12),
            readwiseId: 202,
            bookId: 2
        )
    ]

    
    public static let allHighlights: [LocalHighlightItem] = sampleHighlightsBook1 + sampleHighlightsBook2
}
