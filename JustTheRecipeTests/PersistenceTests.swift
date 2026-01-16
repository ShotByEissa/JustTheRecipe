import XCTest
import SwiftData
@testable import JustTheRecipe

final class PersistenceTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create in-memory container for testing
        let schema = Schema([Recipe.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }
    
    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Recipe Creation Tests
    
    @MainActor
    func testCreateRecipeFromDraft() throws {
        let draft = RecipeDraft(
            title: "Test Recipe",
            sourceURL: "https://example.com/recipe",
            sourceDomain: "example.com",
            ingredients: ["flour", "sugar"],
            instructions: ["Mix", "Bake"]
        )
        
        let recipe = Recipe(from: draft)
        context.insert(recipe)
        try context.save()
        
        // Fetch and verify
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try context.fetch(descriptor)
        
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "Test Recipe")
        XCTAssertEqual(recipes.first?.ingredients.count, 2)
        XCTAssertEqual(recipes.first?.instructions.count, 2)
    }
    
    // MARK: - Recipe Update Tests
    
    @MainActor
    func testUpdateRecipe() throws {
        // Create initial recipe
        let recipe = Recipe(
            title: "Original Title",
            sourceURL: "https://example.com",
            sourceDomain: "example.com"
        )
        context.insert(recipe)
        try context.save()
        
        // Update
        recipe.title = "Updated Title"
        recipe.updatedAt = Date()
        try context.save()
        
        // Verify update persisted
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try context.fetch(descriptor)
        
        XCTAssertEqual(recipes.first?.title, "Updated Title")
    }
    
    // MARK: - Recipe Delete Tests
    
    @MainActor
    func testDeleteRecipe() throws {
        // Create recipe
        let recipe = Recipe(
            title: "To Delete",
            sourceURL: "https://example.com",
            sourceDomain: "example.com"
        )
        context.insert(recipe)
        try context.save()
        
        // Verify it exists
        var descriptor = FetchDescriptor<Recipe>()
        var recipes = try context.fetch(descriptor)
        XCTAssertEqual(recipes.count, 1)
        
        // Delete
        context.delete(recipe)
        try context.save()
        
        // Verify deleted
        descriptor = FetchDescriptor<Recipe>()
        recipes = try context.fetch(descriptor)
        XCTAssertEqual(recipes.count, 0)
    }
    
    // MARK: - Search Tests
    
    @MainActor
    func testSearchByTitle() throws {
        // Create recipes
        let pasta = Recipe(
            title: "Spaghetti Bolognese",
            sourceURL: "https://example.com/pasta",
            sourceDomain: "example.com"
        )
        
        let soup = Recipe(
            title: "Tomato Soup",
            sourceURL: "https://example.com/soup",
            sourceDomain: "example.com"
        )
        
        context.insert(pasta)
        context.insert(soup)
        try context.save()
        
        // Search for "Spaghetti"
        let query = "spaghetti"
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)
        
        let results = allRecipes.filter {
            $0.title.lowercased().contains(query.lowercased())
        }
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Spaghetti Bolognese")
    }
    
    @MainActor
    func testSearchByIngredient() throws {
        // Create recipes
        let pasta = Recipe(
            title: "Pasta Dish",
            sourceURL: "https://example.com/pasta",
            sourceDomain: "example.com",
            ingredients: ["spaghetti", "tomato sauce", "garlic"]
        )
        
        let stirFry = Recipe(
            title: "Stir Fry",
            sourceURL: "https://example.com/stirfry",
            sourceDomain: "example.com",
            ingredients: ["chicken", "broccoli", "garlic"]
        )
        
        context.insert(pasta)
        context.insert(stirFry)
        try context.save()
        
        // Search for "chicken"
        let query = "chicken"
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)
        
        let results = allRecipes.filter {
            $0.ingredients.contains { $0.lowercased().contains(query.lowercased()) }
        }
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Stir Fry")
    }
    
    @MainActor
    func testSearchWithExcludeIngredient() throws {
        // Create recipes
        let withNuts = Recipe(
            title: "Nut Cookies",
            sourceURL: "https://example.com/nuts",
            sourceDomain: "example.com",
            ingredients: ["flour", "peanuts", "sugar"]
        )
        
        let noNuts = Recipe(
            title: "Plain Cookies",
            sourceURL: "https://example.com/plain",
            sourceDomain: "example.com",
            ingredients: ["flour", "butter", "sugar"]
        )
        
        context.insert(withNuts)
        context.insert(noNuts)
        try context.save()
        
        // Exclude "peanuts"
        let exclude = "peanuts"
        let descriptor = FetchDescriptor<Recipe>()
        let allRecipes = try context.fetch(descriptor)
        
        let results = allRecipes.filter {
            !$0.ingredients.contains { $0.lowercased().contains(exclude.lowercased()) }
        }
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Plain Cookies")
    }
    
    // MARK: - Sorting Tests
    
    @MainActor
    func testSortByDate() throws {
        // Create recipes with different dates
        let older = Recipe(
            title: "Older Recipe",
            sourceURL: "https://example.com/old",
            sourceDomain: "example.com",
            updatedAt: Date(timeIntervalSinceNow: -3600)  // 1 hour ago
        )
        
        let newer = Recipe(
            title: "Newer Recipe",
            sourceURL: "https://example.com/new",
            sourceDomain: "example.com",
            updatedAt: Date()
        )
        
        context.insert(older)
        context.insert(newer)
        try context.save()
        
        // Fetch sorted by date descending
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let recipes = try context.fetch(descriptor)
        
        XCTAssertEqual(recipes.count, 2)
        XCTAssertEqual(recipes.first?.title, "Newer Recipe")
        XCTAssertEqual(recipes.last?.title, "Older Recipe")
    }
    
    @MainActor
    func testSortAlphabetically() throws {
        // Create recipes
        let banana = Recipe(
            title: "Banana Bread",
            sourceURL: "https://example.com/banana",
            sourceDomain: "example.com"
        )
        
        let apple = Recipe(
            title: "Apple Pie",
            sourceURL: "https://example.com/apple",
            sourceDomain: "example.com"
        )
        
        context.insert(banana)
        context.insert(apple)
        try context.save()
        
        // Fetch sorted alphabetically
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.title)]
        )
        let recipes = try context.fetch(descriptor)
        
        XCTAssertEqual(recipes.count, 2)
        XCTAssertEqual(recipes.first?.title, "Apple Pie")
        XCTAssertEqual(recipes.last?.title, "Banana Bread")
    }
    
    // MARK: - Duplicate Prevention Tests
    
    @MainActor
    func testDuplicateURLDetection() throws {
        let url = "https://example.com/same-recipe"
        
        // Create first recipe
        let first = Recipe(
            title: "First Version",
            sourceURL: url,
            sourceDomain: "example.com"
        )
        context.insert(first)
        try context.save()
        
        // Check if URL already exists before adding another
        let existingDescriptor = FetchDescriptor<Recipe>()
        let existingRecipes = try context.fetch(existingDescriptor)
        let urlExists = existingRecipes.contains { $0.sourceURL == url }
        
        XCTAssertTrue(urlExists)
    }
    
    // MARK: - Data Integrity Tests
    
    @MainActor
    func testRecipePreservesAllFields() throws {
        let draft = RecipeDraft(
            title: "Complete Recipe",
            sourceURL: "https://example.com/complete",
            sourceDomain: "example.com",
            imageURL: "https://example.com/image.jpg",
            servings: "4 servings",
            totalTime: "30 min",
            ingredients: ["ing1", "ing2"],
            instructions: ["step1", "step2"],
            notes: "Some notes",
            rawHTML: "<html>content</html>",
            extractionConfidence: .jsonLD
        )
        
        let recipe = Recipe(from: draft)
        context.insert(recipe)
        try context.save()
        
        // Fetch and verify all fields
        let descriptor = FetchDescriptor<Recipe>()
        let recipes = try context.fetch(descriptor)
        let fetched = recipes.first!
        
        XCTAssertEqual(fetched.title, "Complete Recipe")
        XCTAssertEqual(fetched.sourceURL, "https://example.com/complete")
        XCTAssertEqual(fetched.sourceDomain, "example.com")
        XCTAssertEqual(fetched.imageURL, "https://example.com/image.jpg")
        XCTAssertEqual(fetched.servings, "4 servings")
        XCTAssertEqual(fetched.totalTime, "30 min")
        XCTAssertEqual(fetched.ingredients, ["ing1", "ing2"])
        XCTAssertEqual(fetched.instructions, ["step1", "step2"])
        XCTAssertEqual(fetched.notes, "Some notes")
        XCTAssertEqual(fetched.rawHTML, "<html>content</html>")
    }
    
    // MARK: - PersistenceController Tests
    
    func testPersistenceControllerPreview() async {
        let controller = await PersistenceController.preview
        
        await MainActor.run {
            let context = controller.container.mainContext
            let descriptor = FetchDescriptor<Recipe>()
            let recipes = try? context.fetch(descriptor)
            
            XCTAssertNotNil(recipes)
            XCTAssertEqual(recipes?.count, 2)  // Preview has 2 sample recipes
        }
    }
    
    func testInMemoryController() {
        let controller = PersistenceController(inMemory: true)
        XCTAssertTrue(controller.isHealthy)
        XCTAssertNil(controller.initializationError)
    }
}
