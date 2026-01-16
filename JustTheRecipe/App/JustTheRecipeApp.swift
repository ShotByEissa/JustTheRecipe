//
//  JustTheRecipeApp.swift
//  JustTheRecipe
//
//  A recipe extraction app that removes ads and clutter from cooking websites.
//  Offline-first, privacy-focused, no subscriptions.
//
//  Target: iOS 26+
//  Price: $1.99 (paid upfront, no IAP)
//

import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct JustTheRecipeApp: App {
    
    /// SwiftData container
    private let persistenceController = PersistenceController.shared
    
    /// Track if we've shown the persistence warning
    @State private var hasShownPersistenceWarning = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkPersistenceHealth()
                }
                .alert(
                    "Storage Issue",
                    isPresented: $hasShownPersistenceWarning
                ) {
                    Button("OK") { }
                } message: {
                    Text("Unable to save recipes permanently. Your recipes will be lost when you close the app. Try restarting.")
                }
        }
        .modelContainer(persistenceController.container)
    }
    
    private func checkPersistenceHealth() {
        // Only show warning once per app launch
        if !persistenceController.isHealthy && !hasShownPersistenceWarning {
            hasShownPersistenceWarning = true
        }
    }
}
