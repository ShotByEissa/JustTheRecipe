import Foundation

// MARK: - Apple Intelligence Normalizer
// Stub for future on-device ML-based normalization.
// Uses Apple's on-device foundation models when available.
//
// TODO: Implement when Apple Intelligence APIs are available
// - Use Foundation Models framework (iOS 18.4+)
// - System prompt for recipe cleaning
// - Fall back to RuleBasedNormalizer if unavailable

struct AppleIntelligenceNormalizer: RecipeNormalizer {
    
    /// Check if Apple Intelligence is available on this device
    static var isAvailable: Bool {
        // TODO: Check for actual API availability
        // - Device capability (A17 Pro or later, M-series)
        // - iOS version (18.4+)
        // - User has enabled Apple Intelligence
        // - Foundation Models framework is available
        
        // For now, always return false
        return false
    }
    
    /// The fallback normalizer to use when AI is unavailable
    private let fallback = RuleBasedNormalizer()
    
    func normalize(draft: RecipeDraft) async throws -> RecipeDraft {
        // Check availability
        guard Self.isAvailable else {
            // Fall back to rule-based normalization
            return try await fallback.normalize(draft: draft)
        }
        
        // TODO: Implement AI-powered normalization
        // 
        // Planned implementation:
        // 1. Create system prompt for recipe normalization
        // 2. Send ingredients and instructions to on-device model
        // 3. Parse structured response
        // 4. Validate output before returning
        //
        // Example system prompt:
        // """
        // You are a recipe editor. Clean up the following recipe content:
        // - Remove advertising and fluff text
        // - Standardize ingredient measurements
        // - Ensure each instruction is a single clear step
        // - Preserve all essential cooking information
        // - Return JSON with "ingredients" and "instructions" arrays
        // """
        
        // For now, fall back to rule-based
        return try await fallback.normalize(draft: draft)
    }
}

// MARK: - Normalization Service
// Coordinator for selecting and applying the best available normalizer.

actor NormalizationService {
    
    /// Shared instance
    static let shared = NormalizationService()
    
    /// The active normalizer
    private var normalizer: RecipeNormalizer {
        if AppleIntelligenceNormalizer.isAvailable {
            return AppleIntelligenceNormalizer()
        } else {
            return RuleBasedNormalizer()
        }
    }
    
    /// Normalize a recipe draft using the best available normalizer
    /// - Parameter draft: The draft to normalize
    /// - Returns: Normalized draft
    func normalize(_ draft: RecipeDraft) async throws -> RecipeDraft {
        try await normalizer.normalize(draft: draft)
    }
    
    /// Check which normalizer is being used
    var normalizerType: NormalizerType {
        if AppleIntelligenceNormalizer.isAvailable {
            return .appleIntelligence
        } else {
            return .ruleBased
        }
    }
    
    enum NormalizerType {
        case ruleBased
        case appleIntelligence
        
        var displayName: String {
            switch self {
            case .ruleBased:
                return "Standard"
            case .appleIntelligence:
                return "Apple Intelligence"
            }
        }
    }
}
