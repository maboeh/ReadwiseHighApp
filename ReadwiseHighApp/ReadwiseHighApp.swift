// ReadwiseHighApp.swift
// Diese Datei enthielt ursprünglich viele Definitionen, die jetzt ausgelagert sind.

import SwiftUI
import CoreData
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Hilfsfunktionen (falls benötigt)

// Vorhandene DateFormatter Extension (kann hier bleiben oder verschoben werden)
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

// Alte Definitionen entfernt: 
// - ReadwiseDataManager (jetzt in Services/ReadwiseDataManager.swift)
// - PersistenceController (jetzt in Persistence.swift)
// - Hilfsfunktionen (getReadwiseDataManager, hasAPIKey)
// - Alte UI-Komponenten
// - Alte App-Struktur

// // Hilfs-Notification Name (Sollte besser zentral definiert werden, z.B. in Models.swift) - ENTFERNT
// extension Notification.Name {
//     static let showAPIKeyViewNotification = Notification.Name("showAPIKeyViewNotification")
// } 