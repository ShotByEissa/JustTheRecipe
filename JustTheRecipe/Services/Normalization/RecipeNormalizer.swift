import Foundation

// MARK: - Recipe Normalizer Protocol
// Abstraction for recipe content normalization.
// Implementations clean up extracted content for better readability.

protocol RecipeNormalizer: Sendable {
    /// Normalize a recipe draft
    /// - Parameter draft: The draft to normalize
    /// - Returns: Normalized draft
    func normalize(draft: RecipeDraft) async throws -> RecipeDraft
}

// MARK: - Rule-Based Normalizer
// Default normalizer using deterministic rules.
// No ML or AI required - works offline and consistently.

struct RuleBasedNormalizer: RecipeNormalizer {
    
    // MARK: - Configuration
    
    /// Minimum ingredient length to keep
    private let minIngredientLength = 2
    
    /// Maximum ingredient length before it's probably a paragraph
    private let maxIngredientLength = 200
    
    /// Minimum instruction length to keep
    private let minInstructionLength = 10
    
    /// Maximum instruction length before splitting
    private let maxInstructionLength = 500
    
    // MARK: - Public API
    
    func normalize(draft: RecipeDraft) async throws -> RecipeDraft {
        var normalized = draft
        
        // Normalize title
        normalized.title = normalizeTitle(draft.title)
        
        // Normalize ingredients
        normalized.ingredients = normalizeIngredients(draft.ingredients)
        
        // Normalize instructions
        normalized.instructions = normalizeInstructions(draft.instructions)
        
        // Normalize optional fields
        if let servings = draft.servings {
            normalized.servings = normalizeServings(servings)
        }
        
        if let time = draft.totalTime {
            normalized.totalTime = normalizeTime(time)
        }
        
        if let notes = draft.notes {
            normalized.notes = normalizeNotes(notes)
        }
        
        return normalized
    }
    
    // MARK: - Title Normalization
    
    private func normalizeTitle(_ title: String) -> String {
        var result = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common suffixes
        let suffixPatterns = [
            #"\s*[|\-–—]\s*[^|\-–—]+$"#,  // " | Site Name" or " - Recipe"
            #"\s*recipe$"#,                  // trailing "recipe"
        ]
        
        for pattern in suffixPatterns {
            result = removePattern(pattern, from: result, options: .caseInsensitive)
        }
        
        // Normalize whitespace
        result = normalizeWhitespace(result)
        
        // Capitalize properly if all caps or all lowercase
        if result == result.uppercased() || result == result.lowercased() {
            result = result.capitalized
        }
        
        return result
    }
    
    // MARK: - Ingredients Normalization
    
    private func normalizeIngredients(_ ingredients: [String]) -> [String] {
        var normalized: [String] = []
        var seen = Set<String>()  // For deduplication
        
        for ingredient in ingredients {
            // Clean the ingredient
            let cleaned = cleanIngredient(ingredient)
            
            // Skip if too short or too long
            guard cleaned.count >= minIngredientLength,
                  cleaned.count <= maxIngredientLength else {
                continue
            }
            
            // Skip if it's a section header or non-ingredient
            guard !isIngredientSectionHeader(cleaned) else {
                continue
            }
            
            // Skip duplicates (case-insensitive)
            let key = cleaned.lowercased()
            guard !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            
            normalized.append(cleaned)
        }
        
        return normalized
    }
    
    private func cleanIngredient(_ ingredient: String) -> String {
        var result = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove bullet points and list markers
        result = removePattern(#"^[\s•\-\*▪▸►◦‣⁃]+\s*"#, from: result)
        
        // Remove checkbox characters
        result = result.replacingOccurrences(of: "☐", with: "")
        result = result.replacingOccurrences(of: "☑", with: "")
        result = result.replacingOccurrences(of: "□", with: "")
        result = result.replacingOccurrences(of: "■", with: "")
        
        // Remove leading numbers if they look like list indices (not quantities)
        // e.g., "1. flour" but NOT "1 cup flour"
        result = removePattern(#"^\d+[.):]\s+(?![0-9])"#, from: result)
        
        // Normalize fractions
        result = normalizeFractions(result)
        
        // Normalize whitespace
        result = normalizeWhitespace(result)
        
        // Remove trailing punctuation that doesn't belong
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    private func isIngredientSectionHeader(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        let headerPatterns = [
            #"^for the\s"#,
            #"^ingredients\s*:?$"#,
            #"^equipment\s*:?$"#,
            #"^tools\s*:?$"#,
            #"^garnish\s*:?$"#,
            #"^optional\s*:?$"#,
            #"^notes?\s*:?$"#,
            #"^tips?\s*:?$"#,
            #"^substitutions?\s*:?$"#,
        ]
        
        for pattern in headerPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Instructions Normalization
    
    private func normalizeInstructions(_ instructions: [String]) -> [String] {
        var normalized: [String] = []
        var seen = Set<String>()
        
        for instruction in instructions {
            // Clean and potentially split the instruction
            let cleaned = cleanInstruction(instruction)
            let steps = splitIntoSteps(cleaned)
            
            for step in steps {
                // Skip if too short
                guard step.count >= minInstructionLength else {
                    continue
                }
                
                // Skip if it's not a real instruction
                guard !isInstructionFluff(step) else {
                    continue
                }
                
                // Skip duplicates
                let key = step.lowercased()
                guard !seen.contains(key) else {
                    continue
                }
                seen.insert(key)
                
                normalized.append(step)
            }
        }
        
        return normalized
    }
    
    private func cleanInstruction(_ instruction: String) -> String {
        var result = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove step prefixes
        result = removePattern(#"^(?:step\s*)?\d+[.):–—\-]\s*"#, from: result, options: .caseInsensitive)
        
        // Remove bullet points
        result = removePattern(#"^[\s•\-\*▪▸►◦‣⁃]+\s*"#, from: result)
        
        // Normalize whitespace
        result = normalizeWhitespace(result)
        
        // Ensure first letter is capitalized
        if let first = result.first, first.isLowercase {
            result = first.uppercased() + result.dropFirst()
        }
        
        // Ensure ends with period if it doesn't end with punctuation
        if let last = result.last, !last.isPunctuation {
            result += "."
        }
        
        return result
    }
    
    private func splitIntoSteps(_ instruction: String) -> [String] {
        // If instruction is short enough, don't split
        guard instruction.count > maxInstructionLength else {
            return [instruction]
        }
        
        var steps: [String] = []
        
        // Try splitting by sentence-ending patterns followed by action verbs
        let splitPattern = #"(?<=[.!])\s+(?=[A-Z][a-z]*\s)"#
        
        if let regex = try? NSRegularExpression(pattern: splitPattern) {
            let range = NSRange(instruction.startIndex..., in: instruction)
            var lastEnd = instruction.startIndex
            
            for match in regex.matches(in: instruction, range: range) {
                if let matchRange = Range(match.range, in: instruction) {
                    let step = String(instruction[lastEnd..<matchRange.lowerBound])
                        .trimmingCharacters(in: .whitespaces)
                    if !step.isEmpty {
                        steps.append(step)
                    }
                    lastEnd = matchRange.upperBound
                }
            }
            
            // Add remaining text
            let remaining = String(instruction[lastEnd...]).trimmingCharacters(in: .whitespaces)
            if !remaining.isEmpty {
                steps.append(remaining)
            }
        }
        
        // If splitting didn't work, return original
        return steps.isEmpty ? [instruction] : steps
    }
    
    private func isInstructionFluff(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        let fluffPatterns = [
            #"^(advertisement|sponsored|print recipe)"#,
            #"^(share this|pin it|tweet this)"#,
            #"^(leave a comment|rate this recipe)"#,
            #"^(nutrition|calories per serving)"#,
            #"^(click here|subscribe|sign up)"#,
            #"^(image|photo|video)\s*:?"#,
            #"^(see also|related recipes)"#,
            #"^(copyright|all rights reserved)"#,
        ]
        
        for pattern in fluffPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) != nil {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Metadata Normalization
    
    private func normalizeServings(_ servings: String) -> String {
        var result = servings.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove redundant labels
        result = removePattern(#"^(?:serves|servings|yield)[:\s]*"#, from: result, options: .caseInsensitive)
        
        // Normalize common formats
        // "4" -> "4 servings"
        if let regex = try? NSRegularExpression(pattern: #"^(\d+)$"#),
           regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)) != nil {
            result = "\(result) servings"
        }
        
        return result
    }
    
    private func normalizeTime(_ time: String) -> String {
        var result = time.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove redundant labels
        result = removePattern(#"^(?:total time|cook time|prep time|time)[:\s]*"#, from: result, options: .caseInsensitive)
        
        // Normalize abbreviations
        result = result.replacingOccurrences(of: "mins", with: "min")
        result = result.replacingOccurrences(of: "hrs", with: "hours")
        result = result.replacingOccurrences(of: "hr", with: "hour")
        
        // Normalize "1 hour" vs "1 hours"
        result = removePattern(#"(\d)\s*hours?"#, from: result) { match in
            guard let numRange = Range(match.range(at: 1), in: result),
                  let num = Int(result[numRange]) else {
                return result
            }
            return "\(num) hour\(num == 1 ? "" : "s")"
        }
        
        return result
    }
    
    private func normalizeNotes(_ notes: String) -> String {
        var result = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Normalize whitespace
        result = normalizeWhitespace(result)
        
        return result
    }
    
    // MARK: - Utility Functions
    
    private func normalizeWhitespace(_ text: String) -> String {
        // Replace multiple whitespace with single space
        text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
    
    private func normalizeFractions(_ text: String) -> String {
        var result = text
        
        // Common text fractions to Unicode
        let fractions: [(String, String)] = [
            ("1/2", "½"),
            ("1/3", "⅓"),
            ("2/3", "⅔"),
            ("1/4", "¼"),
            ("3/4", "¾"),
            ("1/8", "⅛"),
            ("3/8", "⅜"),
            ("5/8", "⅝"),
            ("7/8", "⅞"),
        ]
        
        for (text, unicode) in fractions {
            result = result.replacingOccurrences(of: text, with: unicode)
        }
        
        return result
    }
    
    private func removePattern(
        _ pattern: String,
        from string: String,
        options: NSRegularExpression.Options = []
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return string
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
    
    private func removePattern(
        _ pattern: String,
        from string: String,
        options: NSRegularExpression.Options = [],
        using block: (NSTextCheckingResult) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return string
        }
        
        var result = string
        let matches = regex.matches(in: string, range: NSRange(string.startIndex..., in: string)).reversed()
        
        for match in matches {
            if let range = Range(match.range, in: result) {
                let replacement = block(match)
                result.replaceSubrange(range, with: replacement)
            }
        }
        
        return result
    }
}
