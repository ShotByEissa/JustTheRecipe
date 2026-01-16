import Foundation
import SwiftData

// MARK: - SwiftData Schema Configuration
// Versioned schema for migration safety.

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Recipe.self]
    }
}

// MARK: - Migration Plan
// Add migrations here as schema evolves.

enum RecipeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }
    
    static var stages: [MigrationStage] {
        // No migrations yet - this is V1
        []
    }
}

// MARK: - Model Container Factory
// Creates the configured SwiftData container.

struct PersistenceController {
    
    /// Shared container for the app
    static let shared = PersistenceController()
    
    /// The configured model container
    let container: ModelContainer
    
    /// Whether the container initialized successfully
    let isHealthy: Bool
    
    /// Error if initialization failed
    let initializationError: Error?
    
    init(inMemory: Bool = false) {
        let schema = Schema([Recipe.self])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        
        do {
            container = try ModelContainer(
                for: schema,
                migrationPlan: RecipeMigrationPlan.self,
                configurations: [configuration]
            )
            isHealthy = true
            initializationError = nil
        } catch {
            // Create in-memory fallback instead of crashing
            // User can still use app but data won't persist
            AppLogger.persistenceError("Failed to initialize persistent storage, using in-memory fallback", error: error)
            
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true,
                allowsSave: true
            )
            
            // This should always succeed for in-memory
            container = try! ModelContainer(
                for: schema,
                configurations: [fallbackConfig]
            )
            isHealthy = false
            initializationError = error
        }
    }
    
    /// Check if persistence is working properly
    @MainActor
    func validatePersistence() -> Bool {
        let context = container.mainContext
        
        // Try a simple fetch
        let descriptor = FetchDescriptor<Recipe>()
        do {
            _ = try context.fetch(descriptor)
            return true
        } catch {
            AppLogger.persistenceError("Persistence validation failed", error: error)
            return false
        }
    }
    
    /// Get the database file URL (for debugging)
    var databaseURL: URL? {
        container.configurations.first?.url
    }
    
    /// Get database size in bytes
    var databaseSize: Int64? {
        guard let url = databaseURL else { return nil }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    /// Formatted database size string
    var formattedDatabaseSize: String {
        guard let size = databaseSize else { return "Unknown" }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Preview/testing container with sample data
    @MainActor
    static var preview: PersistenceController {
        let controller = PersistenceController(inMemory: true)
        
        // Add sample recipes for previews
        let context = controller.container.mainContext
        
        let sample1 = Recipe(
            title: "Classic Tomato Pasta",
            sourceURL: "https://example.com/pasta",
            sourceDomain: "example.com",
            servings: "4 servings",
            totalTime: "30 minutes",
            ingredients: [
                "1 lb spaghetti",
                "2 cans crushed tomatoes",
                "4 cloves garlic, minced",
                "¼ cup olive oil",
                "Fresh basil",
                "Salt and pepper to taste"
            ],
            instructions: [
                "Bring a large pot of salted water to boil.",
                "Cook pasta according to package directions.",
                "Meanwhile, heat olive oil in a large skillet over medium heat.",
                "Add garlic and cook until fragrant, about 1 minute.",
                "Add crushed tomatoes, salt, and pepper. Simmer 15 minutes.",
                "Drain pasta and toss with sauce.",
                "Garnish with fresh basil and serve."
            ]
        )
        
        let sample2 = Recipe(
            title: "Simple Chicken Stir Fry",
            sourceURL: "https://cooking.example.com/stirfry",
            sourceDomain: "cooking.example.com",
            servings: "2 servings",
            totalTime: "20 minutes",
            ingredients: [
                "1 lb chicken breast, sliced",
                "2 cups mixed vegetables",
                "3 tbsp soy sauce",
                "1 tbsp sesame oil",
                "2 cloves garlic",
                "1 inch fresh ginger"
            ],
            instructions: [
                "Slice chicken into thin strips.",
                "Heat sesame oil in a wok over high heat.",
                "Add chicken and cook until golden, 5-6 minutes.",
                "Add garlic and ginger, stir 30 seconds.",
                "Add vegetables and soy sauce.",
                "Stir fry until vegetables are tender-crisp.",
                "Serve over rice."
            ]
        )
        
        context.insert(sample1)
        context.insert(sample2)
        
        return controller
    }
}
