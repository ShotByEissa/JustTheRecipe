import SwiftUI

// MARK: - Extraction Loading View
// Shows progress while fetching and parsing a recipe URL.

struct ExtractionLoadingView: View {
    let url: String
    @Binding var state: ExtractionState
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            switch state {
            case .idle:
                EmptyView()
                
            case .fetching:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Fetching page...")
                    .font(.headline)
                Text(displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
            case .parsing:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Extracting recipe...")
                    .font(.headline)
                Text("Looking for ingredients and instructions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            case .normalizing:
                ProgressView()
                    .scaleEffect(1.5)
                Text("Cleaning up...")
                    .font(.headline)
                Text("Formatting recipe content")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text("Recipe extracted!")
                    .font(.headline)
                
            case .failure(let error):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text("Extraction Failed")
                    .font(.headline)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityStateLabel)
        .onChange(of: state) { _, newState in
            // Announce state changes to VoiceOver
            let announcement = accessibilityAnnouncement(for: newState)
            UIAccessibility.post(notification: .announcement, argument: announcement)
        }
    }
    
    private var displayURL: String {
        if let urlObj = URL(string: url) {
            return urlObj.host ?? url
        }
        return url
    }
    
    private var accessibilityStateLabel: String {
        switch state {
        case .idle: return ""
        case .fetching: return "Fetching page"
        case .parsing: return "Extracting recipe"
        case .normalizing: return "Cleaning up recipe"
        case .success: return "Recipe extracted successfully"
        case .failure(let error): return "Extraction failed: \(error)"
        }
    }
    
    private func accessibilityAnnouncement(for state: ExtractionState) -> String {
        switch state {
        case .idle: return ""
        case .fetching: return "Fetching recipe page"
        case .parsing: return "Extracting recipe content"
        case .normalizing: return "Cleaning up recipe"
        case .success: return "Recipe extracted successfully"
        case .failure(let error): return "Extraction failed. \(error)"
        }
    }
}

// MARK: - Extraction State

enum ExtractionState: Equatable {
    case idle
    case fetching
    case parsing
    case normalizing
    case success
    case failure(String)
    
    var isLoading: Bool {
        switch self {
        case .fetching, .parsing, .normalizing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Previews

#Preview("Fetching") {
    ExtractionLoadingView(
        url: "https://example.com/recipe",
        state: .constant(.fetching)
    )
}

#Preview("Parsing") {
    ExtractionLoadingView(
        url: "https://example.com/recipe",
        state: .constant(.parsing)
    )
}

#Preview("Success") {
    ExtractionLoadingView(
        url: "https://example.com/recipe",
        state: .constant(.success)
    )
}

#Preview("Failure") {
    ExtractionLoadingView(
        url: "https://example.com/recipe",
        state: .constant(.failure("No recipe found on this page."))
    )
}
