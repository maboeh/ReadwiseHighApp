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
    @State private var isShareSheetPresented: Bool = false // Zustand für Share-Sheet
    @Environment(\.presentationMode) private var presentationMode // bleibt

    // Fabric Export States
    @State private var isExportingToFabric: Bool = false
    @State private var fabricExportSuccess: Bool = false
    @State private var fabricExportError: String?
    @State private var showFabricExportAlert: Bool = false

    // Initializer für MainContentView, der den DataManager explizit übergibt
    init(book: BookPreview, dataManager: ReadwiseDataManager) {
        self.book = book
        _viewModel = StateObject(wrappedValue: BookDetailViewModel(book: book, dataManager: dataManager))
    }

    var body: some View {
        #if DEBUG
        let _ = print("🔄 BookDetailView body für Buch '\(book.title)' (ID: \(book.readwiseId ?? -1))")
        #endif
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
                            // Fabric Export Button
                            Button(action: exportToFabric) {
                                if isExportingToFabric {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        #if os(macOS)
                                        .scaleEffect(0.7)
                                        #endif
                                } else {
                                    Label("Fabric", systemImage: "square.and.arrow.up.on.square")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isExportingToFabric)
                            #if os(macOS)
                            .controlSize(.large)
                            #endif
                            .help("Nach Fabric exportieren")

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



                    // Anzeige Anzahl gefundener Highlights (basiert auf ViewModel)
                    if !searchText.isEmpty && !viewModel.highlights.isEmpty {
                        // TODO: Füge filteredHighlights zum ViewModel hinzu, wenn Suche wieder aktiv
                        Text("Suche aktiv - Anzeige gefilterter Highlights muss im VM implementiert werden")

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

                    // Fabric Export Erfolgs-Toast
                    if fabricExportSuccess {
                        HStack {
                            Spacer()
                            Label("Nach Fabric exportiert!", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
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
                            // TODO: Füge filteredHighlights zum ViewModel hinzu, wenn Suche wieder aktiv
                            ForEach(viewModel.filteredHighlights) { highlight in
                                #if DEBUG
                                let _ = print("-- Wird angezeigt: Highlight ID \(highlight.id), Text: '\(highlight.text)'")
                                #endif

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(highlight.text)
                                        .padding(.bottom, 5)
                                    HStack(spacing: 10) {
                                        Text("Seite: \(highlight.page)")
                                        if !highlight.chapterTitle.isEmpty {
                                            Text("Kapitel: \(highlight.chapterTitle)")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !viewModel.highlights.isEmpty {
                    Button {
                        isShareSheetPresented = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $isShareSheetPresented) {
            ActivityView(activityItems: [viewModel.allHighlightsText])
        }
        #endif
        .alert("Fabric Export", isPresented: $showFabricExportAlert) {
            Button("OK") {
                fabricExportError = nil
            }
        } message: {
            if let error = fabricExportError {
                Text(error)
            }
        }
        .task(id: book.id) {
            // Lade Highlights nur beim ersten Wechsel der Buch-ID
            if viewModel.highlights.isEmpty {
                #if DEBUG
                print("➡️ BookDetailView: Lade Highlights für Buch '\(book.title)' (ID: \(book.readwiseId ?? -1))")
                #endif
                viewModel.loadHighlights()
            }
        }
    }

    // MARK: - Fabric Export

    private func exportToFabric() {
        guard !viewModel.highlights.isEmpty else { return }

        isExportingToFabric = true

        FabricExportService.shared.exportHighlights(for: book, highlights: viewModel.highlights) { result in
            DispatchQueue.main.async {
                isExportingToFabric = false

                switch result {
                case .success(let fileURL):
                    #if DEBUG
                    print("✅ Fabric Export erfolgreich: \(fileURL.path)")
                    #endif

                    // Erfolgs-Animation anzeigen
                    withAnimation {
                        fabricExportSuccess = true
                    }

                    // Nach 2 Sekunden ausblenden
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            fabricExportSuccess = false
                        }
                    }

                case .failure(let error):
                    #if DEBUG
                    print("❌ Fabric Export fehlgeschlagen: \(error.localizedDescription)")
                    #endif

                    fabricExportError = error.localizedDescription
                    showFabricExportAlert = true
                }
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


#endif



