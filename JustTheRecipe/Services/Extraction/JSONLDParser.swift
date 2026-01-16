import Foundation

// MARK: - JSON-LD Parser
// Extracts Recipe schema.org data from HTML JSON-LD script tags.
// Handles arrays, @graph structures, and nested recipes.

enum JSONLDParser {
    
    // MARK: - Public API
    
    /// Parse JSON-LD from HTML and extract recipe data
    /// - Parameter html: Raw HTML string
    /// - Returns: RecipeDraft if a recipe was found, nil otherwise
    static func parse(html: String) -> RecipeDraft? {
        // Extract all JSON-LD script contents
        let jsonBlocks = extractJSONLDBlocks(from: html)
        
        guard !jsonBlocks.isEmpty else {
            return nil
        }
        
        // Parse each block and collect recipe candidates
        var candidates: [RecipeCandidate] = []
        
        for jsonString in jsonBlocks {
            if let recipes = parseJSONBlock(jsonString) {
                candidates.append(contentsOf: recipes)
            }
        }
        
        guard !candidates.isEmpty else {
            return nil
        }
        
        // Select the best candidate
        let best = selectBestCandidate(from: candidates)
        
        // Convert to RecipeDraft
        return best.toRecipeDraft()
    }
    
    // MARK: - JSON-LD Extraction
    
    /// Extract JSON-LD script contents from HTML
    private static func extractJSONLDBlocks(from html: String) -> [String] {
        var blocks: [String] = []
        
        // Pattern to match <script type="application/ld+json">...</script>
        // Using a simple approach that handles most cases
        let pattern = #"<script[^>]*type\s*=\s*["\']application/ld\+json["\'][^>]*>([\s\S]*?)</script>"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return blocks
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            if let contentRange = Range(match.range(at: 1), in: html) {
                let content = String(html[contentRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !content.isEmpty {
                    blocks.append(content)
                }
            }
        }
        
        return blocks
    }
    
    // MARK: - JSON Parsing
    
    /// Parse a JSON block and extract recipe candidates
    private static func parseJSONBlock(_ jsonString: String) -> [RecipeCandidate]? {
        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            return extractRecipes(from: json)
        } catch {
            // Try to fix common JSON issues and retry
            if let fixedJSON = attemptJSONFix(jsonString),
               let data = fixedJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) {
                return extractRecipes(from: json)
            }
            return nil
        }
    }
    
    /// Attempt to fix common JSON issues
    private static func attemptJSONFix(_ jsonString: String) -> String? {
        var fixed = jsonString
        
        // Remove trailing commas before } or ]
        fixed = fixed.replacingOccurrences(
            of: #",\s*([}\]])"#,
            with: "$1",
            options: .regularExpression
        )
        
        // Remove HTML comments that sometimes sneak in
        fixed = fixed.replacingOccurrences(
            of: #"<!--[\s\S]*?-->"#,
            with: "",
            options: .regularExpression
        )
        
        return fixed != jsonString ? fixed : nil
    }
    
    /// Recursively extract Recipe objects from JSON
    private static func extractRecipes(from json: Any) -> [RecipeCandidate] {
        var candidates: [RecipeCandidate] = []
        
        if let dict = json as? [String: Any] {
            // Check if this is a Recipe
            if isRecipeType(dict) {
                if let candidate = RecipeCandidate(from: dict) {
                    candidates.append(candidate)
                }
            }
            
            // Check for @graph array
            if let graph = dict["@graph"] as? [[String: Any]] {
                for item in graph {
                    candidates.append(contentsOf: extractRecipes(from: item))
                }
            }
            
            // Recursively check nested objects
            for (_, value) in dict {
                if let nestedDict = value as? [String: Any] {
                    candidates.append(contentsOf: extractRecipes(from: nestedDict))
                } else if let nestedArray = value as? [Any] {
                    candidates.append(contentsOf: extractRecipes(from: nestedArray))
                }
            }
        } else if let array = json as? [Any] {
            // Array of items (common pattern)
            for item in array {
                candidates.append(contentsOf: extractRecipes(from: item))
            }
        }
        
        return candidates
    }
    
    /// Check if a dictionary represents a Recipe type
    private static func isRecipeType(_ dict: [String: Any]) -> Bool {
        guard let type = dict["@type"] else {
            return false
        }
        
        // @type can be a string or array
        if let typeString = type as? String {
            return typeString.lowercased() == "recipe"
        } else if let typeArray = type as? [String] {
            return typeArray.contains { $0.lowercased() == "recipe" }
        }
        
        return false
    }
    
    // MARK: - Candidate Selection
    
    /// Select the best recipe candidate based on completeness
    private static func selectBestCandidate(from candidates: [RecipeCandidate]) -> RecipeCandidate {
        // Score each candidate
        let scored = candidates.map { ($0, $0.completenessScore) }
        
        // Return highest scoring (or first if tied)
        return scored.max(by: { $0.1 < $1.1 })?.0 ?? candidates[0]
    }
}

// MARK: - Recipe Candidate

/// Intermediate structure for parsed recipe data
struct RecipeCandidate {
    var name: String?
    var description: String?
    var image: String?
    var recipeYield: String?
    var totalTime: String?
    var prepTime: String?
    var cookTime: String?
    var ingredients: [String]
    var instructions: [String]
    var author: String?
    var datePublished: String?
    
    /// Initialize from JSON dictionary
    init?(from dict: [String: Any]) {
        // Name is required
        guard let name = dict["name"] as? String, !name.isEmpty else {
            return nil
        }
        
        self.name = name
        self.description = dict["description"] as? String
        self.image = Self.extractImage(from: dict["image"])
        self.recipeYield = Self.extractYield(from: dict)
        self.totalTime = Self.extractTime(from: dict["totalTime"]) ??
                         Self.extractTime(from: dict["cookTime"])
        self.prepTime = Self.extractTime(from: dict["prepTime"])
        self.cookTime = Self.extractTime(from: dict["cookTime"])
        self.ingredients = Self.extractIngredients(from: dict)
        self.instructions = Self.extractInstructions(from: dict)
        self.author = Self.extractAuthor(from: dict["author"])
        self.datePublished = dict["datePublished"] as? String
    }
    
    /// Completeness score for candidate selection
    var completenessScore: Int {
        var score = 0
        
        if name != nil { score += 10 }
        if !ingredients.isEmpty { score += 30 + min(ingredients.count, 20) }
        if !instructions.isEmpty { score += 30 + min(instructions.count, 10) }
        if image != nil { score += 5 }
        if recipeYield != nil { score += 5 }
        if totalTime != nil { score += 5 }
        if description != nil { score += 3 }
        
        return score
    }
    
    /// Convert to RecipeDraft
    func toRecipeDraft() -> RecipeDraft {
        RecipeDraft(
            title: name ?? "Untitled Recipe",
            sourceURL: "",  // Set by caller
            sourceDomain: "",  // Set by caller
            imageURL: image,
            servings: recipeYield,
            totalTime: totalTime,
            ingredients: ingredients,
            instructions: instructions,
            extractionConfidence: .jsonLD
        )
    }
    
    // MARK: - Field Extraction Helpers
    
    /// Extract image URL from various formats
    private static func extractImage(from value: Any?) -> String? {
        guard let value = value else { return nil }
        
        // Direct string
        if let url = value as? String {
            return url
        }
        
        // Object with url property
        if let dict = value as? [String: Any] {
            return dict["url"] as? String
        }
        
        // Array of images - take first
        if let array = value as? [Any], let first = array.first {
            return extractImage(from: first)
        }
        
        return nil
    }
    
    /// Extract yield/servings
    private static func extractYield(from dict: [String: Any]) -> String? {
        if let yield = dict["recipeYield"] {
            if let str = yield as? String {
                return str
            }
            if let arr = yield as? [String], let first = arr.first {
                return first
            }
            if let num = yield as? Int {
                return "\(num) servings"
            }
        }
        return nil
    }
    
    /// Extract and format ISO 8601 duration
    private static func extractTime(from value: Any?) -> String? {
        guard let str = value as? String else { return nil }
        return formatISODuration(str)
    }
    
    /// Format ISO 8601 duration (PT30M, PT1H30M, etc.) to readable string
    private static func formatISODuration(_ iso: String) -> String? {
        // Pattern: PT(#H)?(#M)?(#S)?
        let pattern = #"^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: iso, range: NSRange(iso.startIndex..., in: iso)) else {
            // Not ISO format, return as-is if it looks reasonable
            if iso.contains("min") || iso.contains("hour") {
                return iso
            }
            return nil
        }
        
        var parts: [String] = []
        
        // Hours
        if let range = Range(match.range(at: 1), in: iso),
           let hours = Int(iso[range]), hours > 0 {
            parts.append("\(hours) hour\(hours == 1 ? "" : "s")")
        }
        
        // Minutes
        if let range = Range(match.range(at: 2), in: iso),
           let minutes = Int(iso[range]), minutes > 0 {
            parts.append("\(minutes) min")
        }
        
        // Seconds (rare, but handle it)
        if let range = Range(match.range(at: 3), in: iso),
           let seconds = Int(iso[range]), seconds > 0 {
            parts.append("\(seconds) sec")
        }
        
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
    
    /// Extract ingredients from various formats
    private static func extractIngredients(from dict: [String: Any]) -> [String] {
        guard let value = dict["recipeIngredient"] ?? dict["ingredients"] else {
            return []
        }
        
        // Array of strings (standard)
        if let array = value as? [String] {
            return array
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        // Single string (split by newlines)
        if let str = value as? String {
            return str
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        
        return []
    }
    
    /// Extract instructions from various formats
    private static func extractInstructions(from dict: [String: Any]) -> [String] {
        guard let value = dict["recipeInstructions"] else {
            return []
        }
        
        // Array of strings
        if let array = value as? [String] {
            return processInstructionStrings(array)
        }
        
        // Array of HowToStep objects
        if let array = value as? [[String: Any]] {
            return array.compactMap { step in
                // HowToStep has "text" property
                if let text = step["text"] as? String {
                    return text.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                // Some use "description"
                if let desc = step["description"] as? String {
                    return desc.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                return nil
            }.filter { !$0.isEmpty }
        }
        
        // Array of HowToSection objects (grouped steps)
        if let sections = value as? [[String: Any]] {
            var allSteps: [String] = []
            for section in sections {
                if let items = section["itemListElement"] as? [[String: Any]] {
                    let steps = items.compactMap { step -> String? in
                        step["text"] as? String
                    }
                    allSteps.append(contentsOf: steps)
                }
            }
            if !allSteps.isEmpty {
                return processInstructionStrings(allSteps)
            }
        }
        
        // Single string (split by newlines or numbered steps)
        if let str = value as? String {
            return splitInstructionString(str)
        }
        
        return []
    }
    
    /// Process instruction strings (clean up)
    private static func processInstructionStrings(_ strings: [String]) -> [String] {
        return strings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { removeStepPrefix($0) }
            .filter { !$0.isEmpty }
    }
    
    /// Remove "Step 1:", "1.", etc. prefixes
    private static func removeStepPrefix(_ str: String) -> String {
        // Pattern: "Step 1:", "Step 1.", "1.", "1:", "1)", etc.
        let pattern = #"^(?:step\s*)?\d+[.:)]\s*"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return str
        }
        
        let range = NSRange(str.startIndex..., in: str)
        return regex.stringByReplacingMatches(in: str, range: range, withTemplate: "")
    }
    
    /// Split a single instruction string into steps
    private static func splitInstructionString(_ str: String) -> [String] {
        // Try splitting by numbered patterns first
        let numberedPattern = #"\n\s*(?:step\s*)?\d+[.:)]\s*"#
        
        if let regex = try? NSRegularExpression(pattern: numberedPattern, options: .caseInsensitive) {
            let range = NSRange(str.startIndex..., in: str)
            if regex.numberOfMatches(in: str, range: range) > 1 {
                // Has numbered steps
                let parts = regex.stringByReplacingMatches(in: str, range: range, withTemplate: "\n###SPLIT###")
                    .components(separatedBy: "###SPLIT###")
                return processInstructionStrings(parts)
            }
        }
        
        // Fall back to splitting by double newlines or periods followed by newlines
        let steps = str
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return processInstructionStrings(steps)
    }
    
    /// Extract author name
    private static func extractAuthor(from value: Any?) -> String? {
        guard let value = value else { return nil }
        
        if let str = value as? String {
            return str
        }
        
        if let dict = value as? [String: Any] {
            return dict["name"] as? String
        }
        
        if let array = value as? [Any], let first = array.first {
            return extractAuthor(from: first)
        }
        
        return nil
    }
}
