import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct JustTheRecipeApp: App {
    
    /// SwiftData container
    private let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(persistenceController.container)
    }
}
