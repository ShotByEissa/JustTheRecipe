import Foundation

// MARK: - App Error Types
// Centralized error handling for the entire app.

/// Top-level app errors for user-facing messages
enum AppError: LocalizedError, Equatable {
    // URL errors
    case invalidURL(URLValidationError)
    
    // Network errors
    case noInternet
    case networkTimeout
    case serverError(Int)
    case networkError(String)
    
    // Extraction errors
    case noRecipeFound
    case parsingFailed(String)
    case contentTooLarge
    
    // Persistence errors
    case saveFailed(String)
    case loadFailed(String)
    
    // Generic
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL(let error):
            return error.message
        case .noInternet:
            return "No internet connection. Connect to Wi-Fi or cellular data to fetch recipes."
        case .networkTimeout:
            return "The request timed out. The website might be slow or unavailable."
        case .serverError(let code):
            return "The server returned an error (\(code)). Try again later."
        case .networkError(let message):
            return message
        case .noRecipeFound:
            return "No recipe was found on this page. You can enter it manually instead."
        case .parsingFailed(let reason):
            return "Couldn't parse the recipe: \(reason)"
        case .contentTooLarge:
            return "The page is too large to process."
        case .saveFailed(let reason):
            return "Couldn't save: \(reason)"
        case .loadFailed(let reason):
            return "Couldn't load: \(reason)"
        case .unknown(let message):
            return message
        }
    }
    
    /// Suggested action text for the error
    var actionSuggestion: String {
        switch self {
        case .invalidURL:
            return "Check the URL and try again."
        case .noInternet:
            return "Check your connection."
        case .networkTimeout, .serverError:
            return "Try again in a moment."
        case .noRecipeFound, .parsingFailed:
            return "Enter the recipe manually."
        case .contentTooLarge:
            return "Try a different URL."
        default:
            return "Try again."
        }
    }
    
    /// Whether the error might be resolved by retrying
    var isRetryable: Bool {
        switch self {
        case .networkTimeout, .serverError, .networkError:
            return true
        default:
            return false
        }
    }
    
    /// Whether to offer manual entry as fallback
    var shouldOfferManualEntry: Bool {
        switch self {
        case .noRecipeFound, .parsingFailed, .contentTooLarge:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Factory Methods
    
    /// Create from NetworkError
    static func from(_ error: NetworkError) -> AppError {
        switch error {
        case .invalidURL:
            return .invalidURL(.malformed)
        case .timeout:
            return .networkTimeout
        case .noInternet:
            return .noInternet
        case .serverError(let code):
            return .serverError(code)
        case .redirectLoop:
            return .networkError("Too many redirects.")
        case .responseTooLarge:
            return .contentTooLarge
        default:
            return .networkError(error.localizedDescription)
        }
    }
    
    /// Create from ExtractionServiceError
    static func from(_ error: ExtractionServiceError) -> AppError {
        switch error {
        case .noRecipeFound:
            return .noRecipeFound
        case .parsingFailed(let reason):
            return .parsingFailed(reason)
        }
    }
    
    // Equatable conformance for specific cases
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
        case (.noInternet, .noInternet):
            return true
        case (.networkTimeout, .networkTimeout):
            return true
        case (.noRecipeFound, .noRecipeFound):
            return true
        case (.contentTooLarge, .contentTooLarge):
            return true
        case (.serverError(let a), .serverError(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - URL Validation Errors

enum URLValidationError: Equatable {
    case empty
    case malformed
    case unsupportedScheme
    case blockedDomain(String)
    case missingHost
    
    var message: String {
        switch self {
        case .empty:
            return "Please enter a URL."
        case .malformed:
            return "That doesn't look like a valid URL."
        case .unsupportedScheme:
            return "Only http and https URLs are supported."
        case .blockedDomain(let domain):
            return "\(domain) doesn't typically contain recipes."
        case .missingHost:
            return "The URL is missing a website address."
        }
    }
}

// MARK: - Safe Execution Helpers

/// Execute a throwing operation and convert errors to AppError
func withAppError<T>(_ operation: () async throws -> T) async -> Result<T, AppError> {
    do {
        let result = try await operation()
        return .success(result)
    } catch let error as NetworkError {
        return .failure(.from(error))
    } catch let error as ExtractionServiceError {
        return .failure(.from(error))
    } catch let error as AppError {
        return .failure(error)
    } catch {
        return .failure(.unknown(error.localizedDescription))
    }
}

// MARK: - Content Validation

/// Validates recipe content before saving
enum ContentValidator {
    
    /// Maximum lengths for safety
    static let maxTitleLength = 500
    static let maxIngredientLength = 1000
    static let maxInstructionLength = 5000
    static let maxIngredientCount = 200
    static let maxInstructionCount = 100
    static let maxNotesLength = 10000
    
    /// Validate a RecipeDraft before saving
    /// - Returns: Array of validation issues (empty if valid)
    static func validate(_ draft: RecipeDraft) -> [String] {
        var issues: [String] = []
        
        // Title
        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Recipe needs a title.")
        } else if draft.title.count > maxTitleLength {
            issues.append("Title is too long.")
        }
        
        // Ingredients
        if draft.ingredients.isEmpty {
            issues.append("Add at least one ingredient.")
        } else if draft.ingredients.count > maxIngredientCount {
            issues.append("Too many ingredients (max \(maxIngredientCount)).")
        }
        
        for (index, ingredient) in draft.ingredients.enumerated() {
            if ingredient.count > maxIngredientLength {
                issues.append("Ingredient \(index + 1) is too long.")
                break
            }
        }
        
        // Instructions
        if draft.instructions.isEmpty {
            issues.append("Add at least one instruction.")
        } else if draft.instructions.count > maxInstructionCount {
            issues.append("Too many instructions (max \(maxInstructionCount)).")
        }
        
        for (index, instruction) in draft.instructions.enumerated() {
            if instruction.count > maxInstructionLength {
                issues.append("Step \(index + 1) is too long.")
                break
            }
        }
        
        // Notes
        if let notes = draft.notes, notes.count > maxNotesLength {
            issues.append("Notes are too long.")
        }
        
        return issues
    }
    
    /// Truncate content to safe lengths
    static func sanitize(_ draft: RecipeDraft) -> RecipeDraft {
        let sanitized = draft.copy()
        
        // Truncate title
        if sanitized.title.count > maxTitleLength {
            sanitized.title = String(sanitized.title.prefix(maxTitleLength))
        }
        
        // Truncate ingredients
        sanitized.ingredients = sanitized.ingredients
            .prefix(maxIngredientCount)
            .map { ingredient in
                ingredient.count > maxIngredientLength
                    ? String(ingredient.prefix(maxIngredientLength))
                    : ingredient
            }
        
        // Truncate instructions
        sanitized.instructions = sanitized.instructions
            .prefix(maxInstructionCount)
            .map { instruction in
                instruction.count > maxInstructionLength
                    ? String(instruction.prefix(maxInstructionLength))
                    : instruction
            }
        
        // Truncate notes
        if let notes = sanitized.notes, notes.count > maxNotesLength {
            sanitized.notes = String(notes.prefix(maxNotesLength))
        }
        
        return sanitized
    }
}

// MARK: - Crash Prevention

/// Safe array access that won't crash on out-of-bounds
extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Safe string operations
extension String {
    /// Safely truncate to max length
    func truncated(to maxLength: Int) -> String {
        count <= maxLength ? self : String(prefix(maxLength))
    }
    
    /// Safe substring that won't crash
    func safeSubstring(from: Int, length: Int) -> String {
        let start = index(startIndex, offsetBy: min(from, count))
        let end = index(start, offsetBy: min(length, distance(from: start, to: endIndex)))
        return String(self[start..<end])
    }
}
