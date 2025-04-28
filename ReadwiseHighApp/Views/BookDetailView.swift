import SwiftUI
import Foundation
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Detailansicht eines Buches
struct BookDetailView: View {
    let book: BookPreview
    @StateObject private var viewModel: BookDetailViewModel
    @EnvironmentObject private var dataManager: ReadwiseDataManager
    @State private var searchText: String = "" // Suche bleibt vorerst im View State
    @Environment(\.presentationMode) private var presentationMode // bleibt

    // Initializer für MainContentView, der den DataManager explizit übergibt
    init(book: BookPreview, dataManager: ReadwiseDataManager) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book, dataManager: dataManager))
    }

    var body: some View {
        // Log beim Start der body-Berechnung
        let _ = print("🔄 BookDetailView body für Buch '\(book.title)' (ID: \(book.readwiseId ?? -1))")
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading) {
                    Text(book.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    Text("von \(book.author)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .padding(.top)

                Divider()
                    .padding(.horizontal)

                // Highlights-Bereich
                VStack(alignment: .leading) {
                    HStack {
                        Text("Highlights")
                            .font(.title2)
                            .fontWeight(.bold)

                        // Verwende ViewModel-Daten
                        if !viewModel.highlights.isEmpty {
                            Text("(\(viewModel.highlights.count))")
                                .foregroundColor(.secondary)
                                .font(.headline)
                        } else if viewModel.isLoadingHighlights {
                            // Kein kleiner Ladeindikator mehr hier
                        }

                        Spacer()

                        if !viewModel.highlights.isEmpty {
                            // Verwende ViewModel-Aktion
                            Button(action: viewModel.copyAllHighlightsToClipboard) {
                                Label("Alle kopieren", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            #if os(macOS)
                            .controlSize(.large)
                            #endif
                        }
                    }
                    .padding(.horizontal)

                    // Suchleiste (verwende die Komponente)
                    // SearchBar(text: $searchText) // Später wieder integrieren
                    //    .padding(.horizontal)
                    //    .padding(.top, 8)

                    // Anzeige Anzahl gefundener Highlights (basiert auf ViewModel)
                    if !searchText.isEmpty && !viewModel.highlights.isEmpty {
                        // TODO: Füge filteredHighlights zum ViewModel hinzu, wenn Suche wieder aktiv
                        Text("Suche aktiv - Anzeige gefilterter Highlights muss im VM implementiert werden")
//                        Text("\(viewModel.filteredHighlights.count) von \(viewModel.highlights.count) Highlights gefunden")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 4)
                    }

                    // Erfolgs-Toast (aus ViewModel)
                    if viewModel.copySuccessMessage {
                         HStack {
                            Spacer()
                            Text("Highlights kopiert!")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.green)
                                .clipShape(Capsule())
                            Spacer()
                        }
                        .padding(.vertical)
                        .transition(.opacity.combined(with: .scale))
                    }

                    // Lade-/Fehler-/Inhaltsanzeige für Highlights (aus ViewModel)
                    if viewModel.isLoadingHighlights {
                        HStack {
                            Spacer()
                            ProgressView("Lade Highlights...")
                            Spacer()
                        }.padding(.vertical, 40)
                    } else if let errorMsg = viewModel.highlightError {
                        VStack { // Gruppiere Fehler und Button
                            Text(errorMsg)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                            // Verwende ViewModel-Aktion
                            Button("Erneut versuchen") {
                                viewModel.loadHighlights()
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 5)
                        }.padding(.vertical)

                    } else if viewModel.highlights.isEmpty {
                        Text("Keine Highlights für dieses Buch vorhanden.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        // Liste der gefilterten Highlights (aus ViewModel)
                        LazyVStack(alignment: .leading, spacing: 15) {
                            // TODO: Verwende viewModel.filteredHighlights wenn Suche aktiv
                            ForEach(viewModel.highlights) { highlight in
                                // Drucke das Highlight, das an die Karte übergeben wird
                                let _ = print("-- Wird angezeigt: Highlight ID \(highlight.id), Text: '\(highlight.text)'")
                                
                                // Verwende die HighlightCard Komponente
                                // HighlightCard(highlight: highlight, searchText: searchText) // Später wieder integrieren
                                // Stattdessen einfacher Text:
                                Text(highlight.text)
                                    .padding(.bottom, 5)
                                Text("Seite: \(highlight.page), Kapitel: \(highlight.chapterTitle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                .padding(.bottom)
            }
        }
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: book.id) {
            // Lade Highlights nur beim ersten Wechsel der Buch-ID
            if viewModel.highlights.isEmpty {
                print("➡️ BookDetailView: Lade Highlights für Buch '\(book.title)' (ID: \(book.readwiseId ?? -1))")
                viewModel.loadHighlights()
            }
        }
    }
}


// Vorschau-Provider anpassen
#if DEBUG
struct BookDetailView_Previews: PreviewProvider {
    static var previews: some View {
        // Korrekter Aufruf des BookPreview-Initializers
        let exampleBook = BookPreview(
            title: "Beispielbuch Titel",
            author: "Max Mustermann",
            category: "article",
            readwiseId: 1,
            numHighlights: 3,
            lastHighlightAt: Date()
        )
        
        // Erstelle einen (ggf. Mock-) DataManager für die Preview
        let exampleDataManager = ReadwiseDataManager.shared // Oder einen Mock verwenden
        
        // Erstelle die View und übergebe den DataManager
        NavigationView {
             BookDetailView(book: exampleBook, dataManager: exampleDataManager)
        }
    }
}

// Der spezielle Preview-Initializer wird nicht mehr benötigt,
// da die Preview jetzt den regulären Initializer verwendet (indirekt)
// oder den neuen init(book:dataManager:).
// Lösche die folgende Extension:
/*
extension BookDetailView {
    init(book: BookPreview, previewHighlights: [HighlightItem]) {
        // ... alter Code ...
    }
}
*/
#endif

// Ensure NO struct HighlightItem or struct LocalHighlightItem definition exists here.
// Delete any uncommented struct definitions below this line.

// Beispiel: Mögliche übrig gebliebene Definition (wird gelöscht)
// struct HighlightItem: Identifiable, Codable, Hashable { ... }

// Beispiel: Andere mögliche übrig gebliebene Definition (wird gelöscht)
// struct LocalHighlightItem: Identifiable, Codable, Equatable { ... }

