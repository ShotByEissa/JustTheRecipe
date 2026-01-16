import Foundation

// MARK: - HTML Fetcher
// Fetches raw HTML from URLs with proper error handling.
// Handles redirects, timeouts, compression, and uses a realistic User-Agent.

actor HTMLFetcher {
    
    // MARK: - Configuration
    
    /// Request timeout in seconds
    private let timeoutInterval: TimeInterval = 30
    
    /// Maximum redirects to follow
    private let maxRedirects: Int = 10
    
    /// Realistic User-Agent string (Chrome on macOS)
    /// DECISION: Using a common browser UA to avoid being blocked by recipe sites
    private let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    
    /// Shared instance
    static let shared = HTMLFetcher()
    
    /// URLSession configured for HTML fetching
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInterval
        config.timeoutIntervalForResource = timeoutInterval * 2
        config.httpMaximumConnectionsPerHost = 2
        
        // Accept compressed responses
        config.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Accept-Encoding": "gzip, deflate, br",
            "Connection": "keep-alive",
            "Upgrade-Insecure-Requests": "1"
        ]
        
        return URLSession(configuration: config)
    }()
    
    // MARK: - Public API
    
    /// Fetch HTML from a URL string
    /// - Parameter urlString: The URL to fetch
    /// - Returns: The HTML content as a string
    /// - Throws: NetworkError on failure
    func fetch(from urlString: String) async throws -> HTMLFetchResult {
        // Validate and create URL
        guard let url = URL(string: urlString) else {
            throw NetworkError.invalidURL
        }
        
        return try await fetch(from: url)
    }
    
    /// Fetch HTML from a URL
    /// - Parameter url: The URL to fetch
    /// - Returns: The HTML content and metadata
    /// - Throws: NetworkError on failure
    func fetch(from url: URL) async throws -> HTMLFetchResult {
        // Validate scheme
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw NetworkError.invalidScheme
        }
        
        // Build request
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        // Perform fetch with redirect handling
        return try await performFetch(request: request, redirectCount: 0)
    }
    
    // MARK: - Private Implementation
    
    private func performFetch(request: URLRequest, redirectCount: Int) async throws -> HTMLFetchResult {
        // Check redirect limit
        guard redirectCount < maxRedirects else {
            throw NetworkError.tooManyRedirects
        }
        
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw mapURLError(error)
        } catch {
            throw NetworkError.unknown(error)
        }
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "HTMLFetcher", code: -1))
        }
        
        // Handle redirects (URLSession handles most, but check for manual redirect needs)
        let statusCode = httpResponse.statusCode
        
        switch statusCode {
        case 200...299:
            // Success - continue to parse
            break
            
        case 301, 302, 303, 307, 308:
            // Manual redirect handling if needed
            if let location = httpResponse.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location, relativeTo: request.url) {
                var newRequest = URLRequest(url: redirectURL)
                newRequest.httpMethod = "GET"
                newRequest.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                return try await performFetch(request: newRequest, redirectCount: redirectCount + 1)
            }
            throw NetworkError.redirectLoop
            
        case 400...499:
            throw NetworkError.clientError(statusCode)
            
        case 500...599:
            throw NetworkError.serverError(statusCode)
            
        default:
            throw NetworkError.serverError(statusCode)
        }
        
        // Validate content type
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        guard contentType.contains("text/html") || 
              contentType.contains("application/xhtml") ||
              contentType.isEmpty else {  // Some servers don't set content-type
            throw NetworkError.responseNotHTML
        }
        
        // Check for empty response
        guard !data.isEmpty else {
            throw NetworkError.emptyResponse
        }
        
        // Decode HTML
        let html = try decodeHTML(data: data, response: httpResponse)
        
        // Build result
        return HTMLFetchResult(
            html: html,
            finalURL: httpResponse.url ?? request.url!,
            contentType: contentType,
            statusCode: statusCode
        )
    }
    
    /// Decode HTML data to string, handling various encodings
    private func decodeHTML(data: Data, response: HTTPURLResponse) throws -> String {
        // Try to determine encoding from Content-Type header
        var encoding: String.Encoding = .utf8
        
        if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
            // Look for charset in content-type
            // e.g., "text/html; charset=utf-8"
            if let charsetRange = contentType.range(of: "charset=", options: .caseInsensitive) {
                let charsetStart = charsetRange.upperBound
                var charsetEnd = contentType.endIndex
                
                // Find end of charset value
                if let semicolonIndex = contentType[charsetStart...].firstIndex(of: ";") {
                    charsetEnd = semicolonIndex
                }
                
                let charsetName = contentType[charsetStart..<charsetEnd]
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                
                encoding = encodingFromName(charsetName)
            }
        }
        
        // Try declared encoding first
        if let html = String(data: data, encoding: encoding) {
            // Check for meta charset declaration that might override
            if let metaEncoding = detectMetaCharset(in: html) {
                if metaEncoding != encoding,
                   let redecodedHTML = String(data: data, encoding: metaEncoding) {
                    return redecodedHTML
                }
            }
            return html
        }
        
        // Fallback: try common encodings
        let fallbackEncodings: [String.Encoding] = [
            .utf8, .isoLatin1, .windowsCP1252, .ascii
        ]
        
        for fallbackEncoding in fallbackEncodings {
            if let html = String(data: data, encoding: fallbackEncoding) {
                return html
            }
        }
        
        throw NetworkError.decodingFailed
    }
    
    /// Map common charset names to Swift encodings
    private func encodingFromName(_ name: String) -> String.Encoding {
        switch name {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1", "iso-latin-1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        case "ascii", "us-ascii":
            return .ascii
        case "utf-16", "utf16":
            return .utf16
        default:
            return .utf8
        }
    }
    
    /// Detect charset from HTML meta tags
    private func detectMetaCharset(in html: String) -> String.Encoding? {
        // Look for <meta charset="...">
        let charsetPattern = #"<meta[^>]+charset=[\"']?([^\"'\s>]+)"#
        
        if let regex = try? NSRegularExpression(pattern: charsetPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let charsetRange = Range(match.range(at: 1), in: html) {
            let charset = String(html[charsetRange]).lowercased()
            return encodingFromName(charset)
        }
        
        // Look for <meta http-equiv="Content-Type" content="...; charset=...">
        let httpEquivPattern = #"<meta[^>]+http-equiv=[\"']?Content-Type[\"']?[^>]+content=[\"']?[^\"']*charset=([^\"'\s;>]+)"#
        
        if let regex = try? NSRegularExpression(pattern: httpEquivPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
           let charsetRange = Range(match.range(at: 1), in: html) {
            let charset = String(html[charsetRange]).lowercased()
            return encodingFromName(charset)
        }
        
        return nil
    }
    
    /// Map URLError to NetworkError
    private func mapURLError(_ error: URLError) -> NetworkError {
        switch error.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternet
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return .clientError(0)
        case .redirectToNonExistentLocation:
            return .redirectLoop
        case .httpTooManyRedirects:
            return .tooManyRedirects
        case .badURL:
            return .invalidURL
        default:
            return .unknown(error)
        }
    }
}

// MARK: - Fetch Result

/// Result of an HTML fetch operation
struct HTMLFetchResult: Sendable {
    /// The HTML content
    let html: String
    
    /// The final URL after redirects
    let finalURL: URL
    
    /// Content-Type header value
    let contentType: String
    
    /// HTTP status code
    let statusCode: Int
    
    /// Estimated size of the HTML in bytes
    var estimatedSize: Int {
        html.utf8.count
    }
    
    /// Whether the HTML is small enough to store
    /// DECISION: Cap at 500KB for rawHTML storage
    var isSizeAcceptable: Bool {
        estimatedSize < 500_000
    }
}
