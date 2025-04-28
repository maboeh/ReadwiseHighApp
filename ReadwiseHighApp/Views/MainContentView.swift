import SwiftUI
import Foundation 


// Hauptansicht der App
public struct MainContentView: View {
    @EnvironmentObject var dataManager: ReadwiseDataManager
    @State private var searchText: String = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedBook: BookPreview? = nil
    
    // Helper struct to make categories identifiable
    struct IdentifiableCategory: Identifiable {
        let id = UUID()
        let name: String
    }

    // Liste der verfügbaren Kategorien
    var categoryList: [String] {
        // Extrahiere einzigartige Kategorien aus den geladenen Büchern
        let categories = Set(dataManager.fullyLoadedBooks.map { $0.category })
        // Sortiere und füge "Alle" am Anfang hinzu
        return ["Alle"] + categories.sorted()
    }

    // Gefilterte Bücher basierend auf Suche UND Kategorie
    private var filteredBooks: [BookPreview] {
        var result = dataManager.fullyLoadedBooks

        // Nach Suchtext filtern
        if !searchText.isEmpty {
            result = result.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Nach Kategorie filtern (wenn nicht "Alle" ausgewählt ist)
        if let category = selectedCategory, category != "Alle" {
            result = result.filter { $0.category == category }
        }

        return result
    }

    // Grid-Layout definieren
    #if os(iOS)
    let columns: [GridItem] = [GridItem(.flexible(), spacing: 20), GridItem(.flexible(), spacing: 20)]
    #else
    // Auf macOS flexibler, passt sich der Breite an
    let columns: [GridItem] = [GridItem(.adaptive(minimum: 180, maximum: 230), spacing: 24)]
    #endif

    public var body: some View {
        GeometryReader { geometry in
            Group {
                #if os(macOS)
                NavigationSplitView {
                    // Primary: Suchleiste, Filter und Buch-Grid
                    VStack(alignment: .leading, spacing: 0) {
                        SearchBar(text: $searchText)
                            .padding([.horizontal, .top])
                            .padding(.bottom, 8)
                        let categories: [IdentifiableCategory] = categoryList.map { IdentifiableCategory(name: $0) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(categories) { categoryWrapper in
                                    let categoryName = categoryWrapper.name
                                    let isSelected = (selectedCategory == nil && categoryName == "Alle") || selectedCategory == categoryName
                                    CategoryFilterButton(title: categoryName.capitalized, isSelected: isSelected) {
                                        if categoryName == "Alle" { selectedCategory = nil } else { selectedCategory = categoryName }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 45)
                        .padding(.bottom, 5)
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(filteredBooks) { book in
                                    BookCardView(book: book)
                                        .onTapGesture { selectedBook = book }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                        }
                    }
                } detail: {
                    if let book = selectedBook {
                        BookDetailView(book: book, dataManager: dataManager)
                            .id(book.id)
                    } else {
                        Text("Wähle ein Buch aus, um Details anzuzeigen")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                #else
                // iOS View wird ausgelagert
                IOSContentView(searchText: $searchText, 
                               selectedCategory: $selectedCategory, 
                               categoryList: categoryList, 
                               filteredBooks: filteredBooks, 
                               columns: columns)
                #endif
            }
            #if os(macOS)
            .onAppear {
                // SplitView-Position setzen und Bücher laden auf macOS
                setSplitViewPosition(width: geometry.size.width)
                if dataManager.fullyLoadedBooks.isEmpty && dataManager.loadingState == .idle {
                    dataManager.loadBooks()
                }
            }
            .onChange(of: geometry.size) { newSize in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    setSplitViewPosition(width: newSize.width)
                }
            }
            #else
            .onAppear {
                // Nur Bücher laden auf iOS
                if dataManager.fullyLoadedBooks.isEmpty && dataManager.loadingState == .idle {
                    dataManager.loadBooks()
                }
            }
            #endif
            .sheet(isPresented: $dataManager.shouldShowAPIKeyView) {
                APIKeyView(isPresented: $dataManager.shouldShowAPIKeyView)
                    .environmentObject(dataManager)
                    #if os(macOS)
                    .frame(width: 650, height: 700)
                    #endif
            }
            // macOS: Toolbar mit Update- und APIKey-Button wiederherstellen
            #if os(macOS)
            .toolbar {
                ToolbarItem(placement: .automatic) { updateButton }
                ToolbarItem(placement: .automatic) { apiKeyButton }
            }
            #endif
        }
    }
    
    // Helper View für den Button, um Wiederholung zu vermeiden
    private var updateButton: some View {
        Button {
            dataManager.loadBooks()
        } label: {
            Label("Aktualisieren", systemImage: "arrow.clockwise")
        }
        .disabled(dataManager.loadingState.isLoading)
    }
    
    // Helper View für den API-Key-Button
    private var apiKeyButton: some View {
        Button {
            dataManager.shouldShowAPIKeyView = true
        } label: {
            Label("API-Key", systemImage: "key")
        }
    }
    
    #if os(macOS)
    // Funktion zum Setzen der SplitView-Position
    private func setSplitViewPosition(width: CGFloat) {
        guard let window = NSApp.keyWindow,
              let splitView = findSplitView(in: window.contentView) else {
            print("SplitView oder Fenster nicht gefunden.")
            return
        }

        // Linke Spalte auf 1/3 der Gesamtbreite setzen
        let targetPosition = width / 3
        if abs(splitView.subviews[0].frame.width - targetPosition) > 1 {
            splitView.setPosition(targetPosition, ofDividerAt: 0)
            print("SplitView Position gesetzt auf: \(targetPosition)")
        }
    }

    // Rekursive Hilfsfunktion zum Finden der NSSplitView
    private func findSplitView(in view: NSView?) -> NSSplitView? {
        guard let view = view else { return nil }
        if let splitView = view as? NSSplitView {
            return splitView
        }
        for subview in view.subviews {
            if let splitView = findSplitView(in: subview) {
                return splitView
            }
        }
        return nil
    }
    #endif

    // MARK: - iOS Content View
    #if os(iOS)
    private struct IOSContentView: View {
        @EnvironmentObject var dataManager: ReadwiseDataManager
        @Binding var searchText: String
        @Binding var selectedCategory: String?
        let categoryList: [String]
        let filteredBooks: [BookPreview]
        let columns: [GridItem]

        // Helper struct to make categories identifiable
        struct IdentifiableCategory: Identifiable {
            let id = UUID()
            let name: String
        }

        var body: some View {
            NavigationView {
                VStack(alignment: .leading, spacing: 0) {
                    SearchBar(text: $searchText)
                        .padding([.horizontal, .top])
                        .padding(.bottom, 8)
                    let categories: [IdentifiableCategory] = categoryList.map { IdentifiableCategory(name: $0) }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories) { categoryWrapper in
                                let categoryName = categoryWrapper.name
                                let isSelected = (selectedCategory == nil && categoryName == "Alle") || selectedCategory == categoryName
                                CategoryFilterButton(title: categoryName.capitalized, isSelected: isSelected) {
                                    if categoryName == "Alle" { selectedCategory = nil } else { selectedCategory = categoryName }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 45)
                    .padding(.bottom, 5)
                    
                    // Conditional content based on loading state and data
                    conditionalContent
                }
                .navigationTitle("Readwise Highlights") // Beispiel-Titel
                .navigationBarTitleDisplayMode(.inline) // Optional: kleinerer Titel
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { updateButton }
                    ToolbarItem(placement: .navigationBarTrailing) { apiKeyButton }
                }
            }
        }
        
        // Füge die Button-Definitionen HIER für IOSContentView hinzu
        private var updateButton: some View {
            Button {
                dataManager.loadBooks()
            } label: {
                Label("Aktualisieren", systemImage: "arrow.clockwise")
            }
            .disabled(dataManager.loadingState.isLoading)
        }
        
        private var apiKeyButton: some View {
            Button {
                dataManager.shouldShowAPIKeyView = true
            } label: {
                Label("API-Key", systemImage: "key")
            }
        }

        // Extracted conditional content view
        @ViewBuilder
        private var conditionalContent: some View {
            if dataManager.loadingState.isLoading {
                Spacer()
                ProgressView("Lade Bücher...")
                    .padding()
                Spacer()
            } else if case .error(let message) = dataManager.loadingState {
                Spacer()
                ErrorView(message: message) { // Extracted Error View
                    dataManager.loadBooks()
                }
                Spacer()
            } else {
                if filteredBooks.isEmpty {
                    Spacer()
                    EmptyStateView(searchText: searchText, selectedCategory: selectedCategory) // Extracted Empty State
                    Spacer()
                } else {
                    BookGridView(filteredBooks: filteredBooks, columns: columns) // Extracted Grid View
                }
            }
        }
        
        // MARK: - Helper Subviews for iOS

        private struct ErrorView: View {
            let message: String
            let retryAction: () -> Void

            var body: some View {
                VStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .foregroundColor(.orange)
                    Text("Fehler beim Laden")
                        .font(.title2)
                        .padding(.top, 5)
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Erneut versuchen", action: retryAction)
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        
        private struct EmptyStateView: View {
            let searchText: String
            let selectedCategory: String?

            var body: some View {
                VStack {
                    Image(systemName: "books.vertical.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty && selectedCategory == nil ? "Keine Bücher gefunden" : "Keine Bücher für Filter/Suche")
                        .font(.title2)
                        .padding(.top, 5)
                    Text(searchText.isEmpty && selectedCategory == nil ? "Synchronisiere Highlights über Readwise." : "Ändere Filter oder Suche.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
        }

        private struct BookGridView: View {
            @EnvironmentObject var dataManager: ReadwiseDataManager // DataManager hinzufügen
            let filteredBooks: [BookPreview]
            let columns: [GridItem]

            var body: some View {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(filteredBooks) { book in
                            NavigationLink(destination: BookDetailView(book: book, dataManager: dataManager)) {
                                BookCardView(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
    }
    #endif
} 
