//
//  TemporaryModels.swift
//  ReadwiseHighApp
//
//  Created by Matthias Böhnke on 27.04.25.
//

import Foundation

// Temporär für die Übergangszeit
#if DEBUG
public struct TemporaryCoreBookPreview: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var readwiseId: Int
    public var title: String
    public var author: String
    public var category: String
    public var coverImageUrl: String?
    
    public init(readwiseId: Int, title: String, author: String, category: String, coverImageUrl: String? = nil) {
        self.readwiseId = readwiseId
        self.title = title
        self.author = author
        self.category = category
        self.coverImageUrl = coverImageUrl
    }
}
#endif
