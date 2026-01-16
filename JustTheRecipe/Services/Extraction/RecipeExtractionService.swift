import Foundation

// MARK: - Recipe Extraction Service
// Coordinates recipe extraction from HTML using multiple strategies.
// Priority: JSON-LD > Heuristic fallback
// Always normalizes output for consistency.

actor RecipeExtractionService {
    
    /// Shared instance
    static let shared = RecipeExtractionService()
    
    // MARK: - Public API
    
    /// Extract a recipe from HTML content
    /// - Parameters:
    ///   - html: Raw HTML string
    ///   - sourceURL: Original URL for metadata
    ///   - normalize: Whether to normalize the output (default: true)
    /// - Returns: RecipeDraft with extracted content
    /// - Throws: ExtractionError if no recipe found
    func extract(
        from html: String,
        sourceURL: URL,
        normalize: Bool = true
    ) async throws -> RecipeDraft {
        // Try JSON-LD first (highest confidence)
        let draft: RecipeDraft
        if var jsonLDDraft = JSONLDParser.parse(html: html) {
            jsonLDDraft.sourceURL = sourceURL.absoluteString
            jsonLDDraft.sourceDomain = URLValidator.extractDomain(from: sourceURL)
            draft = jsonLDDraft
        }
        // Try heuristic fallback (medium confidence)
        else if var heuristicDraft = HeuristicParser.parse(html: html) {
            heuristicDraft.sourceURL = sourceURL.absoluteString
            heuristicDraft.sourceDomain = URLValidator.extractDomain(from: sourceURL)
            draft = heuristicDraft
        }
        // No recipe found
        else {
            throw ExtractionServiceError.noRecipeFound
        }

        // Apply normalization if requested
        if normalize {
            return try await NormalizationService.shared.normalize(draft)
        }

        return draft
    }
    
    /// Full extraction pipeline: fetch + parse + normalize
    /// - Parameter url: URL to fetch and extract from
    /// - Returns: RecipeDraft with extracted content and raw HTML
    func extract(from url: URL) async throws -> RecipeDraft {
        // Fetch HTML
        let fetchResult = try await HTMLFetcher.shared.fetch(from: url)
        
        // Extract and normalize recipe
        var draft = try await extract(from: fetchResult.html, sourceURL: fetchResult.finalURL)
        
        // Store raw HTML if size acceptable
        if fetchResult.isSizeAcceptable {
            draft.rawHTML = fetchResult.html
        }
        
        return draft
    }
}

// MARK: - Extraction Errors

enum ExtractionServiceError: LocalizedError {
    case noRecipeFound
    case parsingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noRecipeFound:
            return "No recipe was found on this page."
        case .parsingFailed(let reason):
            return "Failed to parse recipe: \(reason)"
        }
    }
}
