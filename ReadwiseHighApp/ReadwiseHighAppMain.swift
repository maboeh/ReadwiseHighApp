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






// MARK: - App und ContentView
@main
struct ReadwiseHighApp: App {
    @StateObject private var dataManager = ReadwiseDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(dataManager)
        }
    }
}



// MARK: - Book Row View
struct BookRow: View {
    let book: BookPreview
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(book.title)
                    .font(.headline)
                Text(book.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(book.numHighlights)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}


