//
//  ReadwiseHighAppApp.swift
//  ReadwiseHighApp
//
//  Created by Matthias Böhnke on 25.04.25.
//

import SwiftUI

@main
struct ReadwiseHighAppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
