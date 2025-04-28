// ReadwiseHighAppMain.swift
// Einstiegspunkt für die ReadwiseHighApp

import SwiftUI
import CoreData
//import Utils
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// Importiere die API-Service für die Highlight-Definition
import Foundation

// Das Problem ist, dass ReadwiseHighApp das Hauptmodul ist und nicht importiert werden kann.
// Die Typen müssen in diesem Modul oder durch explizite Imports verfügbar gemacht werden.

// Füge explizite Imports für die verwendeten Typen hinzu
// (Namen ggf. anpassen, falls sie in einem anderen Modul liegen)
// import ReadwiseDataManager // Beispiel, falls in eigenem Modul
// import DataModels // Beispiel, falls Modelle in eigenem Modul

// Eigene Definition des HighlightItem-Typs mit eindeutigem Namen
// struct LocalHighlightItem: Identifiable, Codable, Equatable { ... }

// MARK: - Modelltypen, die wir direkt hier deklarieren - GELÖSCHT (sind in Models.swift etc.)
/*
// LoadingState-Enum für die App
enum LoadingState: Equatable {
    case idle
    case loadingBooks
    case loadingHighlights
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .idle, .error:
            return false
        default:
            return true
        }
    }
    
    static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
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
enum ValidationError: Error, Equatable {
    case noKey
    case invalidKey
    case networkError(String)
    case invalidResponse
    case serverError(Int)
    case invalidURL
    case noData
    
    static func == (lhs: ValidationError, rhs: ValidationError) -> Bool {
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

// Vereinfachte BookPreview-Struktur
struct BookPreview: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let author: String
    let category: String
    let coverImageURL: URL?
    let readwiseId: Int?
    let numHighlights: Int
    var lastHighlightAt: Date?
}
*/

// MARK: - Services - GELÖSCHT (sind in Services/*.swift)
/*
// Vereinfachter ReadwiseAPIService
class ReadwiseAPIService {
    static let shared = ReadwiseAPIService()
    
    func hasAPIKey() -> Bool {
        !getAPIKey().isEmpty
    }
    
    func getAPIKey() -> String {
        return UserDefaults.standard.string(forKey: "readwiseApiKey") ?? ""
    }
    
    func saveAPIKey(_ apiKey: String) {
        UserDefaults.standard.set(apiKey, forKey: "readwiseApiKey")
    }
}

// Vereinfachter DataManager
class ReadwiseDataManager: ObservableObject {
    static let shared = ReadwiseDataManager()
    
    @Published var loadingState: LoadingState = .idle
    @Published var lastUpdate: Date?
    @Published var fullyLoadedBooks: [BookPreview] = []
    @Published var shouldShowAPIKeyView: Bool = false
    
    // Referenz zum API Service
    private let apiService = ReadwiseAPIService.shared
    
    func updateAPIKeyViewState() {
        self.shouldShowAPIKeyView = !apiService.hasAPIKey()
    }
    
    func loadData() {
        loadingState = .loadingBooks
        print("🔄 Daten werden geladen...")
        
        // Demo-Implementierung mit Beispieldaten
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.fullyLoadedBooks = [
                BookPreview(title: "Swift Programming", author: "Apple", category: "Programmierung", 
                           coverImageURL: nil, readwiseId: 1, numHighlights: 5, lastHighlightAt: Date()),
                BookPreview(title: "SwiftUI Essentials", author: "John Doe", category: "Programmierung", 
                           coverImageURL: nil, readwiseId: 2, numHighlights: 10, lastHighlightAt: Date())
            ]
            self.loadingState = .idle
            self.lastUpdate = Date()
        }
    }
}
*/

// MARK: - UI Komponenten - GELÖSCHT (sind in Views/*.swift)
/*
// Suchleiste
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Suchen...", text: $text)
                .foregroundColor(.primary)
                #if os(iOS)
                .textFieldStyle(DefaultTextFieldStyle())
                #else
                .textFieldStyle(RoundedBorderTextFieldStyle())
                #endif
            
            if !text.isEmpty {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        #if os(iOS)
        .background(Color(UIColor.secondarySystemBackground))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(10)
    }
}

// BookCardView
struct BookCardView: View {
    let book: BookPreview
    
    var body: some View {
        VStack(alignment: .leading) {
            // Cover-Bild oder Platzhalter
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(2/3, contentMode: .fit)
                    .cornerRadius(8)
                
                Text(book.title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
            
            // Titel und Autor
            Text(book.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(book.author)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Spacer()
            
            // Anzahl der Highlights
            Text("\(book.numHighlights) Highlights")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground)) // Fehler hier wird mit Löschen behoben
        .cornerRadius(10)
    }
}

// Vereinfachte BookDetailView
struct BookDetailView: View {
    let book: BookPreview
    
    var body: some View {
        VStack {
            Text(book.title)
                .font(.largeTitle)
            Text(book.author)
                .font(.title2)
            
            Spacer()
            
            Text("\(book.numHighlights) Highlights")
                .font(.headline)
                .padding()
        }
        .padding()
        .navigationTitle(book.title)
    }
}

// APIKeyView
struct APIKeyView: View {
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var isValid = false
    @Binding var isPresented: Bool
    @State private var isCheckingNetwork = false
    @State private var networkStatus: String?
    @EnvironmentObject var dataManager: ReadwiseDataManager

    var body: some View {
        VStack {
            // Titel mit Schließen-Button für macOS
            HStack {
                Text("Readwise API")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Schließen") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            
            Form {
                Section("API-Schlüssel eingeben") {
                    TextField("API-Schlüssel", text: $apiKey)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                    
                    Button("Speichern") {
                        saveKey()
                    }
                    .disabled(apiKey.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 300)
        .onAppear {
            let savedKey = ReadwiseAPIService.shared.getAPIKey()
            if !savedKey.isEmpty {
                apiKey = savedKey
            }
        }
    }
    
    private func saveKey() {
        ReadwiseAPIService.shared.saveAPIKey(apiKey)
        isPresented = false
        dataManager.updateAPIKeyViewState()
        dataManager.loadData()
    }
}
*/

// MARK: - App und ContentView

// App-Hauptklasse (bleibt erhalten)
@main
struct ReadwiseHighAppEntry: App {
    // Verwende den zentralen ReadwiseDataManager - KORREKT
    @StateObject private var dataManager = ReadwiseDataManager.shared
    // Verwende das Singleton für NetworkMonitor (falls benötigt, sonst entfernen)
    // @StateObject private var networkMonitor = NetworkMonitor.shared

    init() {
        // App-Setup
        setupAppearance()
        // Bildcache einrichten - verwende die existierende Implementation
        // ImageCacheManagerBridgeImpl.setupBridge()
    }
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(dataManager)
        }
    }
    
    private func setupAppearance() {
        #if os(iOS)
        // Beispiel: TintColor setzen
        // UIView.appearance().tintColor = UIColor(named: "AccentColor") ?? .systemBlue
        #endif
    }
}

// Klasse für Datenverwaltung - vereinfacht - GELÖSCHT
// class DataManager: ObservableObject { ... }

// Zugriff auf die Utils/ReadwiseAPIService.swift-Implementierung - GELÖSCHT
// EXTERNE KLASSE - hier nur deklarieren, nicht definieren
// class ReadwiseAPIService { ... }

// Netzwerküberwachung - minimale Implementierung - GELÖSCHT
// class NetworkMonitor: ObservableObject { ... }

// Hilfs-Notification Name - GELÖSCHT (Definition ist in Models.swift)
/*
extension Notification.Name {
    static let showAPIKeyViewNotification = Notification.Name("showAPIKeyViewNotification")
}
*/

// Einfache Zeilenansicht für ein Buch (bleibt erhalten)
struct BookRow: View {
    let book: BookPreview

    var body: some View {
        HStack {
            // Hier könnte ein kleines Vorschaubild hin (optional)
            // AsyncImage(url: book.coverImageURL) { image in ... }

            VStack(alignment: .leading) {
                Text(book.title).font(.headline)
                Text(book.author).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(book.numHighlights) Highlights")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// Ansicht für einzelne Highlight-Zeilen - GELÖSCHT (vermutlich in eigener Datei oder nicht mehr benötigt)
// struct HighlightRow: View { ... }
