import SwiftUI
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif



struct BookCardView: View {
    let book: BookPreview // Use proper type instead of Any
    
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
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack {
                    Text("\(book.numHighlights) Highlights")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    SourceCategoryBadge(category: book.category)
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
    
    private func loadImage() {
        self.image = nil
        self.showErrorIcon = false
        self.isLoadingImage = false

        guard let url = book.coverImageURL else {
            return
        }

        self.isLoadingImage = true

        // Use ImageCacheManager for efficient image loading with caching
        ImageCacheManager.shared.loadImage(from: url) { result in
            DispatchQueue.main.async {
                self.isLoadingImage = false
                
                switch result {
                case .success(let platformImage):
                    #if os(iOS)
                    self.image = Image(uiImage: platformImage)
                    #elseif os(macOS)
                    self.image = Image(nsImage: platformImage)
                    #endif
                    self.showErrorIcon = false
                case .failure(let error):
                    self.showErrorIcon = true
                    print("❌ Fehler beim Laden des Bildes von \(url.absoluteString): \(error.localizedDescription)")
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
