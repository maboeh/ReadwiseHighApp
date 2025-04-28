import SwiftUI
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Import der benötigten Modelle am einfachsten aus dem Hauptmodul
// Da sich Models.swift im Root-Verzeichnis befindet, sind diese Typen im gesamten Projekt verfügbar

struct BookCardView: View {
    let book: Any // Verwende Any um Typprobleme zu vermeiden
    
    // Environment-Variablen
    @State private var image: Image?
    @State private var isLoadingImage = false
    @State private var showErrorIcon = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cover-Bild Bereich
            ZStack {
                Rectangle()
                    #if os(macOS)
                    .fill(Color(NSColor.controlBackgroundColor))
                    #else
                    .fill(Color(.systemGray6))
                    #endif

                if isLoadingImage {
                    ProgressView()
                } else if showErrorIcon {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                } else if let loadedImage = image {
                    loadedImage
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                        .transition(.opacity)
                } else {
                    Image(systemName: "book.closed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.gray)
                }
            }
            .aspectRatio(3/4, contentMode: .fit)
            .clipped()
            .padding(8)
            .background(Color.white.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
            
            // Informations-Bereich
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text("\(numHighlights) Highlights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    SourceCategoryBadge(category: category)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(4)
        .onAppear(perform: loadImage)
    }
    
    // Hintergrundfarbe abhängig vom Betriebssystem
    private var backgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    // Hilfsfunktionen, die die Eigenschaften des Books auslesen
    
    // Titel des Buches
    private var title: String {
        if let book = book as? (any Identifiable) {
            // Dynamisches Abrufen der Titel-Eigenschaft mit Mirror
            let mirror = Mirror(reflecting: book)
            if let titleProperty = mirror.children.first(where: { $0.label == "title" })?.value as? String {
                return titleProperty
            }
        }
        return "Unbekannter Titel"
    }
    
    // Autor des Buches
    private var author: String {
        if let book = book as? (any Identifiable) {
            let mirror = Mirror(reflecting: book)
            if let authorProperty = mirror.children.first(where: { $0.label == "author" })?.value as? String {
                return authorProperty
            }
        }
        return "Unbekannter Autor"
    }
    
    // Kategorie des Buches
    private var category: String {
        if let book = book as? (any Identifiable) {
            let mirror = Mirror(reflecting: book)
            if let categoryProperty = mirror.children.first(where: { $0.label == "category" })?.value as? String {
                return categoryProperty
            }
        }
        return "Unbekannt"
    }
    
    // Anzahl der Highlights
    private var numHighlights: Int {
        if let book = book as? (any Identifiable) {
            let mirror = Mirror(reflecting: book)
            if let numProperty = mirror.children.first(where: { $0.label == "numHighlights" })?.value as? Int {
                return numProperty
            }
        }
        return 0
    }
    
    // Cover-URL des Buches
    private var coverImageURL: URL? {
        if let book = book as? (any Identifiable) {
            let mirror = Mirror(reflecting: book)
            if let urlProperty = mirror.children.first(where: { $0.label == "coverImageURL" })?.value as? URL {
                return urlProperty
            }
        }
        return nil
    }

    private func loadImage() {
        self.image = nil
        self.showErrorIcon = false
        self.isLoadingImage = false

        guard let url = coverImageURL else {
            return
        }

        self.isLoadingImage = true

        // Verwende DispatchQueue für den Bildladeprozess
        DispatchQueue.global(qos: .userInitiated).async {
            if let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    
                    #if os(iOS)
                    if let uiImage = UIImage(data: data) {
                        self.image = Image(uiImage: uiImage)
                        self.showErrorIcon = false
                    } else {
                        self.showErrorIcon = true
                    }
                    #elseif os(macOS)
                    if let nsImage = NSImage(data: data) {
                        self.image = Image(nsImage: nsImage)
                        self.showErrorIcon = false
                    } else {
                        self.showErrorIcon = true
                    }
                    #endif
                }
            } else {
                DispatchQueue.main.async {
                    self.isLoadingImage = false
                    self.showErrorIcon = true
                    print("❌ Fehler beim Laden des Bildes von \(url.absoluteString)")
                }
            }
        }
    }
}

struct SourceCategoryBadge: View {
    let category: String

    var body: some View {
        Text(category.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .foregroundColor(.white)
            .background(categoryColor(category))
            .cornerRadius(4)
    }

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "articles", "artikel": return .blue
        case "books", "buch": return .green
        case "tweets", "tweet": return .cyan
        case "podcasts", "podcast": return .purple
        case "supplementals": return .orange
        default: return .gray
        }
    }
}

#if DEBUG
struct BookCardView_Previews: PreviewProvider {
    static var previews: some View {
        let mockBook = PreviewBook(
            id: UUID(),
            title: "Beispiel Buch Titel Der Sehr Lang Sein Kann",
            author: "Max Mustermann", 
            category: "books",
            coverImageURL: URL(string: "https://via.placeholder.com/150/771796"),
            numHighlights: 15
        )

        BookCardView(book: mockBook)
            .padding()
            .previewLayout(.sizeThatFits)
            .frame(width: 200)
    }
}

// Einfache Struktur für die Vorschau
struct PreviewBook: Identifiable {
    let id: UUID
    let title: String
    let author: String
    let category: String
    let coverImageURL: URL?
    let numHighlights: Int
}
#endif
