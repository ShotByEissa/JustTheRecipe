import Foundation

// MARK: - URL Validator
// Validates and normalizes URLs for recipe fetching.

enum URLValidator {
    
    /// Validation result
    enum ValidationResult {
        case valid(URL)
        case invalid(String)  // Error message
    }
    
    /// Validate a URL string
    /// - Parameter input: Raw URL string from user
    /// - Returns: Validation result with normalized URL or error
    static func validate(_ input: String) -> ValidationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Empty check
        guard !trimmed.isEmpty else {
            return .invalid("Please enter a URL.")
        }
        
        // Try to create URL (add scheme if missing)
        var urlString = trimmed
        
        // Add https:// if no scheme present
        if !urlString.lowercased().hasPrefix("http://") &&
           !urlString.lowercased().hasPrefix("https://") {
            urlString = "https://" + urlString
        }
        
        // Validate URL creation
        guard let url = URL(string: urlString) else {
            return .invalid("The URL format is not valid.")
        }
        
        // Validate scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .invalid("Only HTTP and HTTPS URLs are supported.")
        }
        
        // Validate host exists
        guard let host = url.host, !host.isEmpty else {
            return .invalid("The URL must include a website address.")
        }
        
        // Basic host validation (has at least one dot, like example.com)
        // DECISION: Allow localhost for development
        if !host.contains(".") && host != "localhost" {
            return .invalid("The website address doesn't look valid.")
        }
        
        // Block common non-recipe URLs
        let blockedHosts = [
            "google.com", "google.co", "bing.com", "yahoo.com",
            "facebook.com", "twitter.com", "instagram.com",
            "youtube.com", "tiktok.com"
        ]
        
        let normalizedHost = host.lowercased()
            .replacingOccurrences(of: "www.", with: "")
        
        if blockedHosts.contains(where: { normalizedHost.hasSuffix($0) }) {
            return .invalid("This doesn't look like a recipe website.")
        }
        
        return .valid(url)
    }
    
    /// Extract domain from URL for display
    /// - Parameter url: The URL
    /// - Returns: Clean domain string (without www.)
    static func extractDomain(from url: URL) -> String {
        guard let host = url.host else { return "" }
        
        // Remove www. prefix
        if host.lowercased().hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        
        return host
    }
    
    /// Extract domain from URL string
    static func extractDomain(from urlString: String) -> String {
        guard let url = URL(string: urlString) else { return "" }
        return extractDomain(from: url)
    }
}
