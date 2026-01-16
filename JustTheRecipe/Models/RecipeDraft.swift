import Foundation

// MARK: - RecipeDraft
// Transient model used during extraction and review/edit flow.
// NOT persisted directly - converted to Recipe when saved.
// Observable for SwiftUI binding during editing.

@Observable
final class RecipeDraft: Identifiable, @unchecked Sendable {
    // MARK: - Identity
    var id: UUID
    
    // MARK: - Core Fields
    var title: String
    var sourceURL: String
    var sourceDomain: String
    
    // MARK: - Optional Metadata
    var imageURL: String?
    var servings: String?
    var totalTime: String?
    
    // MARK: - Recipe Content
    var ingredients: [String]
    var instructions: [String]
    var notes: String?
    
    // MARK: - Raw Data
    var rawHTML: String?
    
    // MARK: - Extraction State
    var extractionConfidence: ExtractionConfidence
    
    // MARK: - Initializer
    init(
        id: UUID = UUID(),
        title: String = "",
        sourceURL: String = "",
        sourceDomain: String = "",
        imageURL: String? = nil,
        servings: String? = nil,
        totalTime: String? = nil,
        ingredients: [String] = [],
        instructions: [String] = [],
        notes: String? = nil,
        rawHTML: String? = nil,
        extractionConfidence: ExtractionConfidence = .unknown
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
        self.rawHTML = rawHTML
        self.extractionConfidence = extractionConfidence
    }
    
    // MARK: - Convenience
    
    /// Create an empty draft for manual entry
    static func blank(from url: String = "") -> RecipeDraft {
        let domain = URL(string: url)?.host ?? ""
        return RecipeDraft(
            title: "New Recipe",
            sourceURL: url,
            sourceDomain: domain,
            extractionConfidence: .manual
        )
    }
    
    /// Check if draft has minimum viable content
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredients.isEmpty &&
        !instructions.isEmpty
    }
    
    /// Check if draft is essentially empty
    var isEmpty: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        ingredients.isEmpty &&
        instructions.isEmpty
    }
}

// MARK: - Extraction Confidence
// Indicates how the recipe was extracted

enum ExtractionConfidence: String, Codable {
    case jsonLD = "json_ld"           // Extracted from structured data (high confidence)
    case heuristic = "heuristic"       // Extracted via HTML heuristics (medium confidence)
    case manual = "manual"             // User entered manually (user confidence)
    case unknown = "unknown"           // Not yet determined
    
    var displayName: String {
        switch self {
        case .jsonLD: return "Structured Data"
        case .heuristic: return "HTML Extraction"
        case .manual: return "Manual Entry"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Copy Support
extension RecipeDraft {
    /// Create a deep copy of the draft
    func copy() -> RecipeDraft {
        RecipeDraft(
            id: UUID(), // New ID for copy
            title: title,
            sourceURL: sourceURL,
            sourceDomain: sourceDomain,
            imageURL: imageURL,
            servings: servings,
            totalTime: totalTime,
            ingredients: ingredients,
            instructions: instructions,
            notes: notes,
            rawHTML: rawHTML,
            extractionConfidence: extractionConfidence
        )
    }
}
