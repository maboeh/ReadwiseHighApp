import SwiftUI

// Highlight-Karte
struct HighlightCard: View {
    // Erwarte ein HighlightItem-Objekt
    let highlight: HighlightItem
    
    // Suchtext für die Hervorhebung
    var searchText: String = ""

    private var isMatchingSearch: Bool {
        if searchText.isEmpty {
            return false
        }
        // Verwende Felder aus dem HighlightItem
        return highlight.text.localizedCaseInsensitiveContains(searchText) ||
               highlight.chapterTitle.localizedCaseInsensitiveContains(searchText)
    }

    // Computed property für den Detail-Text
    private var detailText: String? {
        var details: [String] = []
        if !highlight.chapterTitle.isEmpty {
            details.append("Kapitel: \(highlight.chapterTitle)")
        }
        if highlight.page > 0 {
            details.append("Seite \(highlight.page)")
        }
        
        if details.isEmpty {
            return nil // Gib nil zurück, wenn keine Details vorhanden sind
        } else {
            return details.joined(separator: " | ") // Gib den verbundenen String zurück
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Highlight-Text mit lila/gelbem Rand
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(isMatchingSearch ? Color.yellow.opacity(0.7) : Color.purple.opacity(0.7))
                    .frame(width: 4)

                // Originalcode wiederhergestellt
                if isMatchingSearch {
                    HighlightedText(text: highlight.text, searchText: searchText)
                        .font(.body)
                        .padding(.leading, 12) // Abstand zum Rand
                        .padding(.vertical, 8)
                    Spacer() // <- Spacer innerhalb des if-Zweigs
                } else {
                    // Zeige Text in Anführungszeichen an
                    Text("\"\(highlight.text)\"") 
                        .font(.body)
                        .padding(.leading, 12) // Abstand zum Rand
                        .padding(.vertical, 8)
                    Spacer() // <- Spacer innerhalb des else-Zweigs
                }
            }
            // Plattformspezifischen Hintergrund verwenden
            #if os(macOS)
            .background(Color(NSColor.textBackgroundColor)) // Passender Hintergrund für macOS
            #else
            .background(Color(.systemBackground)) // Standardhintergrund für iOS etc.
            #endif
            .cornerRadius(6)

            // Zweiter HStack für Seite und Kapitel
            if let details = detailText { 
                HStack {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 5)
            }
        }
    }
}

// Hilfsstruktur für hervorgehobenen Text (bleibt unverändert)
struct HighlightedText: View {
    let text: String
    let searchText: String

    var body: some View {
        if searchText.isEmpty {
            // Text hier auch in Anführungszeichen für Konsistenz?
            Text("\"\(text)\"") 
        } else {
            Text(attributedString())
        }
    }

    // Erstellt AttributedString
    private func attributedString() -> AttributedString {
        // Text hier auch in Anführungszeichen?
        var attributedString = AttributedString("\"\(text)\"") 

        if !searchText.isEmpty {
            // Suche im *gesamten* String (inkl. Anführungszeichen)
            if let range = attributedString.range(of: searchText, options: [.caseInsensitive, .diacriticInsensitive]) {
                attributedString[range].backgroundColor = .yellow.opacity(0.5)
            }
        }
        return attributedString
    }
}

// Vorschau-Provider für HighlightCard
#if DEBUG
struct HighlightCard_Previews: PreviewProvider {
    static var previews: some View {
        // Erstelle Beispiel-HighlightItems
        let exampleHighlight1 = HighlightItem(
            id: UUID(),
            text: "Dies ist ein normales Highlight ohne Suchübereinstimmung.",
            page: 15,
            chapter: 1,
            chapterTitle: "Kapitel Eins",
            date: Date(),
            readwiseId: 201,
            bookId: 1
        )
        
        let exampleHighlight2 = HighlightItem(
            id: UUID(),
            text: "Dieses Highlight enthält den Suchbegriff, der hervorgehoben werden soll.",
            page: 30,
            chapter: 2,
            chapterTitle: "Zweites Kapitel mit Suchbegriff",
            date: Date(),
            readwiseId: 202,
            bookId: 1
        )

        VStack(spacing: 20) {
            HighlightCard(highlight: exampleHighlight1, searchText: "Suchbegriff")
            HighlightCard(highlight: exampleHighlight2, searchText: "Suchbegriff")
            HighlightCard(highlight: exampleHighlight2, searchText: "") // Ohne Suchtext
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
