import Foundation

// MARK: - Network Errors
// Typed errors for networking operations with user-friendly messages.

enum NetworkError: LocalizedError {
    case invalidURL
    case invalidScheme          // Not http/https
    case timeout
    case noInternet
    case serverError(Int)       // 5xx errors
    case clientError(Int)       // 4xx errors
    case redirectLoop
    case tooManyRedirects
    case responseNotHTML
    case emptyResponse
    case decodingFailed
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is not valid."
        case .invalidScheme:
            return "Only HTTP and HTTPS URLs are supported."
        case .timeout:
            return "The request timed out. Check your connection and try again."
        case .noInternet:
            return "No internet connection. Connect to the internet and try again."
        case .serverError(let code):
            return "The server returned an error (\(code)). Try again later."
        case .clientError(let code):
            if code == 404 {
                return "Page not found. Check the URL and try again."
            } else if code == 403 {
                return "Access denied. This page may require login."
            }
            return "The request failed (\(code)). Check the URL and try again."
        case .redirectLoop:
            return "The page has a redirect loop."
        case .tooManyRedirects:
            return "Too many redirects. The page may be misconfigured."
        case .responseNotHTML:
            return "The URL doesn't point to a web page."
        case .emptyResponse:
            return "The server returned an empty response."
        case .decodingFailed:
            return "Couldn't read the page content."
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error might be resolved by retrying
    var isRetryable: Bool {
        switch self {
        case .timeout, .noInternet, .serverError:
            return true
        default:
            return false
        }
    }
}
