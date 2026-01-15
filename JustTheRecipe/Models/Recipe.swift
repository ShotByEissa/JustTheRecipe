import Foundation
import SwiftData

// MARK: - Recipe (Persisted Model)
// The finalized, saved recipe stored via SwiftData.
// Migration-safe: use @Attribute defaults for new fields.

@Model
final class Recipe {
    // MARK: - Primary Key
    @Attribute(.unique) var id: UUID
    
    // MARK: - Core Fields
    var title: String
    var sourceURL: String  // Stored as String for SwiftData compatibility
    var sourceDomain: String
    
    // MARK: - Optional Metadata
    var imageURL: String?  // Stored as String for SwiftData compatibility
    var servings: String?
    var totalTime: String?
    
    // MARK: - Recipe Content
    var ingredients: [String]
    var instructions: [String]
    var notes: String?
    
    // MARK: - Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    // MARK: - Raw Data (optional, for debugging/re-extraction)
    // Only store if HTML is under ~500KB to avoid bloat
    var rawHTML: String?
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        title: String,
        sourceURL: String,
        sourceDomain: String,
        imageURL: String? = nil,
        servings: String? = nil,
        totalTime: String? = nil,
        ingredients: [String] = [],
        instructions: [String] = [],
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        rawHTML: String? = nil
    ) {
        self.id = id
        self.title = title
        self.sourceURL = sourceURL
        self.sourceDomain = sourceDomain
        self.imageURL = imageURL
        self.servings = servings
        self.totalTime = totalTime
        self.ingredients = ingredients
        self.instructions = instructions
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.rawHTML = rawHTML
    }
    
    // MARK: - Convenience
    
    /// Returns the source URL as a URL type
    var sourceURLValue: URL? {
        URL(string: sourceURL)
    }
    
    /// Returns the image URL as a URL type
    var imageURLValue: URL? {
        guard let imageURL else { return nil }
        return URL(string: imageURL)
    }
    
    /// Create a Recipe from a RecipeDraft
    convenience init(from draft: RecipeDraft) {
        self.init(
            id: draft.id,
            title: draft.title,
            sourceURL: draft.sourceURL,
            sourceDomain: draft.sourceDomain,
            imageURL: draft.imageURL,
            servings: draft.servings,
            totalTime: draft.totalTime,
            ingredients: draft.ingredients,
            instructions: draft.instructions,
            notes: draft.notes,
            createdAt: Date(),
            updatedAt: Date(),
            rawHTML: draft.rawHTML
        )
    }
}

// MARK: - Searchable Text
extension Recipe {
    /// Combined text for search indexing
    var searchableText: String {
        let parts = [title] + ingredients
        return parts.joined(separator: " ").lowercased()
    }
}
