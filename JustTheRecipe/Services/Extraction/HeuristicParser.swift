import Foundation

// MARK: - Heuristic Parser
// Extracts recipe data from HTML when JSON-LD is not available.
// Uses heading detection, list extraction, and content analysis.

enum HeuristicParser {
    
    // MARK: - Public API
    
    /// Parse HTML and extract recipe data heuristically
    /// - Parameter html: Raw HTML string
    /// - Returns: RecipeDraft if a recipe was found, nil otherwise
    static func parse(html: String) -> RecipeDraft? {
        // Clean HTML first
        let cleanedHTML = preprocessHTML(html)
        
        // Extract title
        let title = extractTitle(from: cleanedHTML)
        
        // Extract ingredients
        let ingredients = extractIngredients(from: cleanedHTML)
        
        // Extract instructions
        let instructions = extractInstructions(from: cleanedHTML)
        
        // Must have at least ingredients OR instructions to be a recipe
        guard !ingredients.isEmpty || !instructions.isEmpty else {
            return nil
        }
        
        // Extract optional metadata
        let servings = extractServings(from: cleanedHTML)
        let totalTime = extractTime(from: cleanedHTML)
        let imageURL = extractImageURL(from: cleanedHTML)
        
        return RecipeDraft(
            title: title ?? "Untitled Recipe",
            sourceURL: "",  // Set by caller
            sourceDomain: "",  // Set by caller
            imageURL: imageURL,
            servings: servings,
            totalTime: totalTime,
            ingredients: ingredients,
            instructions: instructions,
            extractionConfidence: .heuristic
        )
    }
    
    // MARK: - HTML Preprocessing
    
    /// Remove non-content elements from HTML
    private static func preprocessHTML(_ html: String) -> String {
        var result = html
        
        // Remove script tags and contents
        result = removePattern(#"<script[^>]*>[\s\S]*?</script>"#, from: result)
        
        // Remove style tags and contents
        result = removePattern(#"<style[^>]*>[\s\S]*?</style>"#, from: result)
        
        // Remove nav elements
        result = removePattern(#"<nav[^>]*>[\s\S]*?</nav>"#, from: result)
        
        // Remove header elements (site header, not content headers)
        result = removePattern(#"<header[^>]*>[\s\S]*?</header>"#, from: result)
        
        // Remove footer elements
        result = removePattern(#"<footer[^>]*>[\s\S]*?</footer>"#, from: result)
        
        // Remove aside elements (usually ads/sidebars)
        result = removePattern(#"<aside[^>]*>[\s\S]*?</aside>"#, from: result)
        
        // Remove common ad/social divs by class
        let adClassPatterns = [
            #"<div[^>]*class="[^"]*(?:ad-|ads-|advertisement|social-share|share-buttons|related-posts|comments)[^"]*"[^>]*>[\s\S]*?</div>"#
        ]
        for pattern in adClassPatterns {
            result = removePattern(pattern, from: result)
        }
        
        // Remove HTML comments
        result = removePattern(#"<!--[\s\S]*?-->"#, from: result)
        
        return result
    }
    
    /// Remove regex pattern from string
    private static func removePattern(_ pattern: String, from string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return string
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.stringByReplacingMatches(in: string, range: range, withTemplate: "")
    }
    
    // MARK: - Title Extraction
    
    /// Extract recipe title from HTML
    private static func extractTitle(from html: String) -> String? {
        // Try h1 first
        if let h1 = extractFirstMatch(#"<h1[^>]*>([^<]+)</h1>"#, from: html, group: 1) {
            let cleaned = cleanText(h1)
            if !cleaned.isEmpty && cleaned.count < 200 {
                return cleaned
            }
        }
        
        // Try og:title meta tag
        if let ogTitle = extractFirstMatch(#"<meta[^>]*property="og:title"[^>]*content="([^"]+)""#, from: html, group: 1) {
            let cleaned = cleanText(ogTitle)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        
        // Try title tag
        if let title = extractFirstMatch(#"<title[^>]*>([^<]+)</title>"#, from: html, group: 1) {
            let cleaned = cleanText(title)
            // Remove common suffixes like " | Site Name" or " - Recipe"
            let withoutSuffix = cleaned
                .components(separatedBy: CharacterSet(charactersIn: "|–—-"))
                .first?
                .trimmingCharacters(in: .whitespaces)
            
            if let result = withoutSuffix, !result.isEmpty {
                return result
            }
        }
        
        return nil
    }
    
    // MARK: - Ingredients Extraction
    
    /// Extract ingredients list from HTML
    private static func extractIngredients(from html: String) -> [String] {
        // Find ingredients section
        guard let section = findSection(
            in: html,
            headingPatterns: [
                "ingredients",
                "ingredient list",
                "what you.?ll need",
                "you.?ll need",
                "shopping list"
            ]
        ) else {
            // Try finding by common class names
            return extractByClass(from: html, classPatterns: [
                "ingredient",
                "ingredients",
                "recipe-ingredient"
            ])
        }
        
        // Extract list items from section
        var ingredients = extractListItems(from: section)
        
        // If no list items, try extracting lines
        if ingredients.isEmpty {
            ingredients = extractLines(from: section)
        }
        
        // Clean and filter
        return ingredients
            .map { cleanIngredient($0) }
            .filter { isValidIngredient($0) }
    }
    
    /// Clean an ingredient line
    private static func cleanIngredient(_ text: String) -> String {
        var result = cleanText(text)
        
        // Remove checkbox characters
        result = result.replacingOccurrences(of: "☐", with: "")
        result = result.replacingOccurrences(of: "☑", with: "")
        result = result.replacingOccurrences(of: "□", with: "")
        
        // Remove leading bullets/dashes
        result = removePattern(#"^[\s•\-\*▪▸►]+\s*"#, from: result)
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Check if text looks like a valid ingredient
    private static func isValidIngredient(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Must have some content
        guard trimmed.count >= 2 else { return false }
        
        // Not too long (probably a paragraph)
        guard trimmed.count < 200 else { return false }
        
        // Skip common non-ingredient patterns
        let skipPatterns = [
            #"^(for the|equipment|tools|note:|tip:|optional:)$"#,
            #"^(advertisement|sponsored|print|share)$"#,
            #"^\d+$"#  // Just a number
        ]
        
        for pattern in skipPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Instructions Extraction
    
    /// Extract instructions from HTML
    private static func extractInstructions(from html: String) -> [String] {
        // Find instructions section
        guard let section = findSection(
            in: html,
            headingPatterns: [
                "instructions",
                "directions",
                "method",
                "steps",
                "how to make",
                "preparation",
                "procedure"
            ]
        ) else {
            // Try finding by common class names
            return extractByClass(from: html, classPatterns: [
                "instruction",
                "instructions",
                "direction",
                "directions",
                "recipe-instruction",
                "recipe-step"
            ])
        }
        
        // Extract from ordered list first
        var instructions = extractOrderedListItems(from: section)
        
        // If no ordered list, try unordered
        if instructions.isEmpty {
            instructions = extractListItems(from: section)
        }
        
        // If still empty, try paragraphs
        if instructions.isEmpty {
            instructions = extractParagraphs(from: section)
        }
        
        // If still empty, try numbered lines
        if instructions.isEmpty {
            instructions = extractNumberedLines(from: section)
        }
        
        // Clean and filter
        return instructions
            .map { cleanInstruction($0) }
            .filter { isValidInstruction($0) }
    }
    
    /// Clean an instruction step
    private static func cleanInstruction(_ text: String) -> String {
        var result = cleanText(text)
        
        // Remove step prefixes like "Step 1:", "1.", "1)", etc.
        result = removePattern(#"^(?:step\s*)?\d+[\.:)\-]\s*"#, from: result)
        
        return result.trimmingCharacters(in: .whitespaces)
    }
    
    /// Check if text looks like a valid instruction
    private static func isValidInstruction(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        
        // Must have meaningful content
        guard trimmed.count >= 10 else { return false }
        
        // Not too long (probably multiple paragraphs merged)
        guard trimmed.count < 1000 else { return false }
        
        // Skip common non-instruction patterns
        let skipPatterns = [
            #"^(advertisement|sponsored|print recipe|share this|pin it)"#,
            #"^(nutrition|calories|serving)"#,
            #"^(leave a comment|rate this|review)"#
        ]
        
        for pattern in skipPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Section Finding
    
    /// Find a section by heading patterns
    private static func findSection(in html: String, headingPatterns: [String]) -> String? {
        for pattern in headingPatterns {
            // Try h2, h3, h4 headings
            for level in 2...4 {
                let headingPattern = #"<h\#(level)[^>]*>[^<]*\b\#(pattern)\b[^<]*</h\#(level)>"#
                    .replacingOccurrences(of: "#(level)", with: "\(level)")
                    .replacingOccurrences(of: "#(pattern)", with: pattern)
                
                if let section = extractSectionAfterHeading(pattern: headingPattern, in: html) {
                    return section
                }
            }
            
            // Try div/section with class containing pattern
            let classPattern = #"<(?:div|section)[^>]*class="[^"]*\b\#(pattern)\b[^"]*"[^>]*>([\s\S]*?)</(?:div|section)>"#
                .replacingOccurrences(of: "#(pattern)", with: pattern)
            
            if let match = extractFirstMatch(classPattern, from: html, group: 1) {
                return match
            }
        }
        
        return nil
    }
    
    /// Extract content after a heading until next heading or section end
    private static func extractSectionAfterHeading(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let matchRange = Range(match.range, in: html) else {
            return nil
        }
        
        let afterHeading = String(html[matchRange.upperBound...])
        
        // Find end of section (next heading or major structural element)
        let endPattern = #"<(?:h[1-6]|section|article|footer|aside)[^>]*>"#
        
        if let endRegex = try? NSRegularExpression(pattern: endPattern, options: .caseInsensitive),
           let endMatch = endRegex.firstMatch(in: afterHeading, range: NSRange(afterHeading.startIndex..., in: afterHeading)),
           let endRange = Range(endMatch.range, in: afterHeading) {
            return String(afterHeading[..<endRange.lowerBound])
        }
        
        // Take up to 5000 characters if no end found
        let maxLength = min(5000, afterHeading.count)
        return String(afterHeading.prefix(maxLength))
    }
    
    /// Extract content by class name patterns
    private static func extractByClass(from html: String, classPatterns: [String]) -> [String] {
        var items: [String] = []
        
        for pattern in classPatterns {
            // Find elements with matching class
            let classPattern = #"<(?:li|div|p|span)[^>]*class="[^"]*\b\#(pattern)\b[^"]*"[^>]*>([\s\S]*?)</(?:li|div|p|span)>"#
                .replacingOccurrences(of: "#(pattern)", with: pattern)
            
            if let regex = try? NSRegularExpression(pattern: classPattern, options: .caseInsensitive) {
                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, range: range)
                
                for match in matches {
                    if let contentRange = Range(match.range(at: 1), in: html) {
                        let content = stripTags(String(html[contentRange]))
                        if !content.isEmpty {
                            items.append(content)
                        }
                    }
                }
            }
            
            if !items.isEmpty { break }
        }
        
        return items
    }
    
    // MARK: - List Extraction
    
    /// Extract items from ul/ol lists
    private static func extractListItems(from html: String) -> [String] {
        var items: [String] = []
        
        let liPattern = #"<li[^>]*>([\s\S]*?)</li>"#
        
        guard let regex = try? NSRegularExpression(pattern: liPattern, options: .caseInsensitive) else {
            return items
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            if let contentRange = Range(match.range(at: 1), in: html) {
                let content = stripTags(String(html[contentRange]))
                if !content.isEmpty {
                    items.append(content)
                }
            }
        }
        
        return items
    }
    
    /// Extract items from ordered lists only
    private static func extractOrderedListItems(from html: String) -> [String] {
        // Find <ol> tags and extract their <li> contents
        let olPattern = #"<ol[^>]*>([\s\S]*?)</ol>"#
        
        guard let regex = try? NSRegularExpression(pattern: olPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let olRange = Range(match.range(at: 1), in: html) else {
            return []
        }
        
        return extractListItems(from: String(html[olRange]))
    }
    
    /// Extract paragraphs as items
    private static func extractParagraphs(from html: String) -> [String] {
        var items: [String] = []
        
        let pPattern = #"<p[^>]*>([\s\S]*?)</p>"#
        
        guard let regex = try? NSRegularExpression(pattern: pPattern, options: .caseInsensitive) else {
            return items
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            if let contentRange = Range(match.range(at: 1), in: html) {
                let content = stripTags(String(html[contentRange]))
                if !content.isEmpty && content.count > 20 {
                    items.append(content)
                }
            }
        }
        
        return items
    }
    
    /// Extract numbered lines from text
    private static func extractNumberedLines(from html: String) -> [String] {
        let text = stripTags(html)
        let lines = text.components(separatedBy: .newlines)
        
        var items: [String] = []
        let numberedPattern = #"^\s*(?:step\s*)?\d+[\.:)\-]\s*(.+)$"#
        
        guard let regex = try? NSRegularExpression(pattern: numberedPattern, options: .caseInsensitive) else {
            return items
        }
        
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex.firstMatch(in: line, range: range),
               let contentRange = Range(match.range(at: 1), in: line) {
                let content = String(line[contentRange]).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    items.append(content)
                }
            }
        }
        
        return items
    }
    
    /// Extract non-empty lines from text content
    private static func extractLines(from html: String) -> [String] {
        let text = stripTags(html)
        return text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 2 }
    }
    
    // MARK: - Metadata Extraction
    
    /// Extract servings/yield
    private static func extractServings(from html: String) -> String? {
        let patterns = [
            #"(?:serves|servings|yield)[:\s]*(\d+(?:\s*-\s*\d+)?(?:\s*(?:people|servings|portions))?)"#,
            #"(?:makes|recipe makes)[:\s]*(\d+(?:\s*-\s*\d+)?(?:\s*(?:servings|cookies|muffins|pieces|cups))?)"#
        ]
        
        for pattern in patterns {
            if let match = extractFirstMatch(pattern, from: html, group: 1) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
    
    /// Extract cooking time
    private static func extractTime(from html: String) -> String? {
        let patterns = [
            #"(?:total time|cook time|prep time)[:\s]*(\d+(?:\s*-\s*\d+)?\s*(?:minutes?|mins?|hours?|hrs?))"#,
            #"(?:ready in|time)[:\s]*(\d+(?:\s*-\s*\d+)?\s*(?:minutes?|mins?|hours?|hrs?))"#
        ]
        
        for pattern in patterns {
            if let match = extractFirstMatch(pattern, from: html, group: 1) {
                return match.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return nil
    }
    
    /// Extract main recipe image URL
    private static func extractImageURL(from html: String) -> String? {
        // Try og:image meta tag
        if let ogImage = extractFirstMatch(#"<meta[^>]*property="og:image"[^>]*content="([^"]+)""#, from: html, group: 1) {
            return ogImage
        }
        
        // Try first large image in article/main content
        let imgPattern = #"<img[^>]*src="([^"]+)"[^>]*>"#
        
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        
        for match in matches {
            if let srcRange = Range(match.range(at: 1), in: html) {
                let src = String(html[srcRange])
                // Skip tiny images, icons, tracking pixels
                if !src.contains("pixel") && 
                   !src.contains("icon") && 
                   !src.contains("logo") &&
                   !src.contains("avatar") &&
                   !src.contains("1x1") {
                    return src
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Text Utilities
    
    /// Extract first regex match
    private static func extractFirstMatch(_ pattern: String, from string: String, group: Int) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let range = Range(match.range(at: group), in: string) else {
            return nil
        }
        return String(string[range])
    }
    
    /// Remove all HTML tags from string
    private static func stripTags(_ html: String) -> String {
        var result = html
        
        // Replace <br> and </p> with newlines
        result = result.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "</p>", with: "\n", options: .caseInsensitive)
        result = result.replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
        
        // Remove all other tags
        result = removePattern(#"<[^>]+>"#, from: result)
        
        // Decode HTML entities
        result = decodeHTMLEntities(result)
        
        return result
    }
    
    /// Clean text (strip tags, normalize whitespace)
    private static func cleanText(_ text: String) -> String {
        var result = stripTags(text)
        
        // Normalize whitespace
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Decode common HTML entities
    private static func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        
        let entities: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&deg;", "°"),
            ("&frac12;", "½"),
            ("&frac14;", "¼"),
            ("&frac34;", "¾"),
            ("&#8217;", "'"),
            ("&#8220;", "\""),
            ("&#8221;", "\""),
            ("&#8211;", "–"),
            ("&#8212;", "—")
        ]
        
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        
        // Handle numeric entities
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "") { match in
                if let numRange = Range(match.range(at: 1), in: result),
                   let codePoint = Int(result[numRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    return String(Character(scalar))
                }
                return ""
            }
        }
        
        return result
    }
}

// MARK: - NSRegularExpression Extension

extension NSRegularExpression {
    func stringByReplacingMatches(
        in string: String,
        range: NSRange,
        withTemplate template: String,
        using block: (NSTextCheckingResult) -> String
    ) -> String {
        var result = string
        let matches = self.matches(in: string, range: range).reversed()
        
        for match in matches {
            if let range = Range(match.range, in: result) {
                let replacement = block(match)
                result.replaceSubrange(range, with: replacement)
            }
        }
        
        return result
    }
}
