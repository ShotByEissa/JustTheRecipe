import Foundation
import SwiftData
import SwiftUI

// MARK: - Recipe Repository
// Handles all persistence operations for recipes.
// Provides a clean API for CRUD operations and search.

@MainActor
final class RecipeRepository: ObservableObject {
    
    /// The model context for persistence operations
    private let modelContext: ModelContext
    
    /// Initialize with a model context
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Create
    
    /// Save a new recipe from a draft
    /// - Parameter draft: The recipe draft to save
    /// - Returns: The saved Recipe
    @discardableResult
    func save(draft: RecipeDraft) throws -> Recipe {
        let recipe = Recipe(from: draft)
        modelContext.insert(recipe)
        try modelContext.save()
        return recipe
    }
    
    /// Save a new recipe directly
    /// - Parameter recipe: The recipe to save
    func save(recipe: Recipe) throws {
        modelContext.insert(recipe)
        try modelContext.save()
    }
    
    // MARK: - Read
    
    /// Fetch all recipes sorted by update date
    /// - Returns: Array of recipes, newest first
    func fetchAll() throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch a recipe by ID
    /// - Parameter id: The recipe UUID
    /// - Returns: The recipe if found
    func fetch(id: UUID) throws -> Recipe? {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    /// Fetch recipes by source domain
    /// - Parameter domain: The source domain to filter by
    /// - Returns: Recipes from that domain
    func fetch(byDomain domain: String) throws -> [Recipe] {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.sourceDomain == domain },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    // MARK: - Search
    
    /// Search recipes by title and ingredients
    /// - Parameter query: Search query string
    /// - Returns: Matching recipes
    func search(query: String) throws -> [Recipe] {
        let lowercasedQuery = query.lowercased()
        
        // Fetch all and filter in memory
        // SwiftData predicate limitations require this approach for array contains
        let allRecipes = try fetchAll()
        
        return allRecipes.filter { recipe in
            // Check title
            if recipe.title.lowercased().contains(lowercasedQuery) {
                return true
            }
            
            // Check ingredients
            if recipe.ingredients.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
                return true
            }
            
            return false
        }
    }
    
    /// Search recipes with ingredient filters
    /// - Parameters:
    ///   - query: Optional search query
    ///   - mustInclude: Ingredient that must be present
    ///   - mustExclude: Ingredient that must not be present
    /// - Returns: Filtered recipes
    func search(
        query: String? = nil,
        mustInclude: String? = nil,
        mustExclude: String? = nil
    ) throws -> [Recipe] {
        var results = try fetchAll()
        
        // Apply text search
        if let query = query, !query.isEmpty {
            let lowercasedQuery = query.lowercased()
            results = results.filter { recipe in
                recipe.title.lowercased().contains(lowercasedQuery) ||
                recipe.ingredients.contains { $0.lowercased().contains(lowercasedQuery) }
            }
        }
        
        // Apply must-include filter
        if let include = mustInclude, !include.isEmpty {
            let lowercasedInclude = include.lowercased()
            results = results.filter { recipe in
                recipe.ingredients.contains { $0.lowercased().contains(lowercasedInclude) }
            }
        }
        
        // Apply must-exclude filter
        if let exclude = mustExclude, !exclude.isEmpty {
            let lowercasedExclude = exclude.lowercased()
            results = results.filter { recipe in
                !recipe.ingredients.contains { $0.lowercased().contains(lowercasedExclude) }
            }
        }
        
        return results
    }
    
    // MARK: - Update
    
    /// Update an existing recipe
    /// - Parameter recipe: The recipe with updated values
    func update(recipe: Recipe) throws {
        recipe.updatedAt = Date()
        try modelContext.save()
    }
    
    /// Update a recipe from a draft (for re-extraction)
    /// - Parameters:
    ///   - recipe: The existing recipe
    ///   - draft: The new draft data
    func update(recipe: Recipe, from draft: RecipeDraft) throws {
        recipe.title = draft.title
        recipe.sourceURL = draft.sourceURL
        recipe.sourceDomain = draft.sourceDomain
        recipe.imageURL = draft.imageURL
        recipe.servings = draft.servings
        recipe.totalTime = draft.totalTime
        recipe.ingredients = draft.ingredients
        recipe.instructions = draft.instructions
        recipe.notes = draft.notes
        recipe.rawHTML = draft.rawHTML
        recipe.updatedAt = Date()
        
        try modelContext.save()
    }
    
    // MARK: - Delete
    
    /// Delete a recipe
    /// - Parameter recipe: The recipe to delete
    func delete(recipe: Recipe) throws {
        modelContext.delete(recipe)
        try modelContext.save()
    }
    
    /// Delete multiple recipes
    /// - Parameter recipes: The recipes to delete
    func delete(recipes: [Recipe]) throws {
        for recipe in recipes {
            modelContext.delete(recipe)
        }
        try modelContext.save()
    }
    
    /// Delete all recipes (use with caution)
    func deleteAll() throws {
        let recipes = try fetchAll()
        for recipe in recipes {
            modelContext.delete(recipe)
        }
        try modelContext.save()
    }
    
    // MARK: - Statistics
    
    /// Get the total number of saved recipes
    var recipeCount: Int {
        (try? fetchAll().count) ?? 0
    }
    
    /// Get unique source domains
    func uniqueDomains() throws -> [String] {
        let recipes = try fetchAll()
        let domains = Set(recipes.map { $0.sourceDomain })
        return Array(domains).sorted()
    }
}

// MARK: - Environment Key

struct RecipeRepositoryKey: EnvironmentKey {
    static let defaultValue: RecipeRepository? = nil
}

extension EnvironmentValues {
    var recipeRepository: RecipeRepository? {
        get { self[RecipeRepositoryKey.self] }
        set { self[RecipeRepositoryKey.self] = newValue }
    }
}
