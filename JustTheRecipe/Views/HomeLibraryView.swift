import SwiftUI
import SwiftData

// MARK: - Home / Library View
// Main view showing URL input and saved recipes.
// iOS 26: Glass effects on navigation chrome only (NavigationStack handles this).

struct HomeLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    
    // MARK: - State
    @State private var urlInput: String = ""
    @State private var searchText: String = ""
    @State private var sortOrder: SortOrder = .mostRecent
    @State private var ingredientFilter: String = ""
    @State private var excludeIngredient: String = ""
    @State private var showingFilters: Bool = false
    
    // Navigation
    @State private var selectedRecipe: Recipe?
    @State private var showingExtraction: Bool = false
    @State private var extractionDraft: RecipeDraft?
    @State private var showingErrorAlert: Bool = false
    @State private var currentError: AppError?
    @State private var extractionState: ExtractionState = .idle
    @State private var lastAttemptedURL: URL?  // For retry functionality
    
    // MARK: - Filtered & Sorted Recipes
    private var filteredRecipes: [Recipe] {
        var result = recipes
        
        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { recipe in
                recipe.title.lowercased().contains(query) ||
                recipe.ingredients.contains { $0.lowercased().contains(query) }
            }
        }
        
        // Include ingredient filter
        if !ingredientFilter.isEmpty {
            let filter = ingredientFilter.lowercased()
            result = result.filter { recipe in
                recipe.ingredients.contains { $0.lowercased().contains(filter) }
            }
        }
        
        // Exclude ingredient filter
        if !excludeIngredient.isEmpty {
            let exclude = excludeIngredient.lowercased()
            result = result.filter { recipe in
                !recipe.ingredients.contains { $0.lowercased().contains(exclude) }
            }
        }
        
        // Sort
        switch sortOrder {
        case .mostRecent:
            result.sort { $0.updatedAt > $1.updatedAt }
        case .alphabetical:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Offline Banner
                if !NetworkMonitor.shared.isConnected {
                    Section {
                        HStack {
                            Image(systemName: "wifi.slash")
                                .foregroundStyle(.orange)
                            Text("Offline – Your saved recipes are still available")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .listRowBackground(Color.orange.opacity(0.1))
                    }
                }
                
                // URL Input Section
                Section {
                    urlInputView
                } header: {
                    Text("Add Recipe")
                }
                
                // Filters Section (collapsible)
                if !recipes.isEmpty {
                    Section {
                        filterControlsView
                    } header: {
                        Text("Filter & Sort")
                    }
                }
                
                // Saved Recipes Section
                Section {
                    if filteredRecipes.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(filteredRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRowView(recipe: recipe)
                            }
                        }
                        .onDelete(perform: deleteRecipes)
                    }
                } header: {
                    if !recipes.isEmpty {
                        Text("Your Recipes (\(filteredRecipes.count))")
                    } else {
                        Text("Your Recipes")
                    }
                }
            }
            .navigationTitle("JustTheRecipe")
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showingExtraction) {
                if let draft = extractionDraft {
                    ReviewEditView(
                        draft: draft,
                        onSave: { saveRecipe(from: draft) },
                        onDiscard: { discardDraft() }
                    )
                }
            }
            .alert(
                "Couldn't Get Recipe",
                isPresented: $showingErrorAlert,
                presenting: currentError
            ) { error in
                if error.isRetryable, lastAttemptedURL != nil {
                    Button("Try Again") {
                        if let url = lastAttemptedURL {
                            performExtraction(from: url)
                        }
                    }
                }
                if error.shouldOfferManualEntry {
                    Button("Enter Manually") {
                        createBlankDraft()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
            .overlay {
                if extractionState.isLoading || extractionState == .success {
                    ExtractionLoadingView(url: urlInput, state: $extractionState)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: extractionState)
        }
    }
    
    // MARK: - URL Input View
    private var urlInputView: some View {
        VStack(spacing: 12) {
            TextField("Paste recipe URL", text: $urlInput)
                .keyboardType(.URL)
                .textContentType(.URL)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .disabled(extractionState.isLoading)
                .accessibilityLabel("Recipe URL input")
            
            Button(action: extractRecipe) {
                Label("Extract Recipe", systemImage: "arrow.down.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || extractionState.isLoading)
            .accessibilityHint("Extracts recipe from the pasted URL")
        }
    }
    
    // MARK: - Filter Controls
    private var filterControlsView: some View {
        DisclosureGroup("Filters", isExpanded: $showingFilters) {
            Picker("Sort by", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .accessibilityLabel("Sort order")
            
            TextField("Must contain ingredient", text: $ingredientFilter)
                .autocapitalization(.none)
                .accessibilityLabel("Filter by ingredient")
            
            TextField("Exclude ingredient", text: $excludeIngredient)
                .autocapitalization(.none)
                .accessibilityLabel("Exclude ingredient")
            
            if !ingredientFilter.isEmpty || !excludeIngredient.isEmpty {
                Button("Clear Filters", role: .destructive) {
                    ingredientFilter = ""
                    excludeIngredient = ""
                }
            }
        }
    }
    
    // MARK: - Empty State
    @ViewBuilder
    private var emptyStateView: some View {
        if recipes.isEmpty {
            ContentUnavailableView(
                "No Recipes Yet",
                systemImage: "book.closed",
                description: Text("Paste a recipe URL above to get started.")
            )
            .accessibilityElement(children: .combine)
        } else {
            ContentUnavailableView(
                "No Matches",
                systemImage: "magnifyingglass",
                description: Text("Try adjusting your search or filters.")
            )
            .accessibilityElement(children: .combine)
        }
    }
    
    // MARK: - Actions
    
    private func extractRecipe() {
        let trimmedURL = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for empty input
        guard !trimmedURL.isEmpty else {
            showError(.invalidURL(.empty))
            return
        }
        
        // Validate URL
        switch URLValidator.validate(trimmedURL) {
        case .invalid(let message):
            // Map to appropriate error type
            if message.contains("doesn't look like") {
                showError(.invalidURL(.malformed))
            } else if message.contains("not supported") {
                showError(.invalidURL(.unsupportedScheme))
            } else if message.contains("doesn't typically contain") {
                showError(.invalidURL(.blockedDomain(trimmedURL)))
            } else {
                showError(.invalidURL(.malformed))
            }
            return
        case .valid(let url):
            // Store for potential retry
            lastAttemptedURL = url
            // Start extraction
            performExtraction(from: url)
        }
    }
    
    private func showError(_ error: AppError) {
        currentError = error
        showingErrorAlert = true
    }
    
    private func performExtraction(from url: URL) {
        // Check network connectivity first
        guard NetworkMonitor.shared.isConnected else {
            showError(.noInternet)
            return
        }
        
        extractionState = .fetching
        
        Task {
            do {
                // Fetch HTML
                let fetchResult = try await HTMLFetcher.shared.fetch(from: url)
                
                await MainActor.run { extractionState = .parsing }
                
                // Try JSON-LD extraction first (high confidence)
                // Then heuristic fallback (medium confidence)
                var draft: RecipeDraft
                
                if let jsonLDDraft = JSONLDParser.parse(html: fetchResult.html) {
                    draft = jsonLDDraft
                    draft.sourceURL = fetchResult.finalURL.absoluteString
                    draft.sourceDomain = URLValidator.extractDomain(from: fetchResult.finalURL)
                } else if let heuristicDraft = HeuristicParser.parse(html: fetchResult.html) {
                    draft = heuristicDraft
                    draft.sourceURL = fetchResult.finalURL.absoluteString
                    draft.sourceDomain = URLValidator.extractDomain(from: fetchResult.finalURL)
                } else {
                    throw ExtractionServiceError.noRecipeFound
                }
                
                await MainActor.run { extractionState = .normalizing }
                
                // Normalize extracted content
                draft = try await NormalizationService.shared.normalize(draft)
                
                // Sanitize to prevent excessively long content
                draft = ContentValidator.sanitize(draft)
                
                // Store raw HTML if acceptable size
                if fetchResult.isSizeAcceptable {
                    draft.rawHTML = fetchResult.html
                }
                
                await MainActor.run {
                    extractionState = .success
                    extractionDraft = draft
                    
                    // Brief delay to show success, then present review
                    Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        await MainActor.run {
                            extractionState = .idle
                            showingExtraction = true
                        }
                    }
                }
            } catch let error as NetworkError {
                await handleExtractionError(.from(error))
            } catch let error as ExtractionServiceError {
                await handleExtractionError(.from(error))
            } catch {
                await handleExtractionError(.unknown(error.localizedDescription))
            }
        }
    }
    
    @MainActor
    private func handleExtractionError(_ error: AppError) {
        extractionState = .failure(error.errorDescription ?? "Unknown error")
        
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                extractionState = .idle
                showError(error)
            }
        }
    }
    
    private func saveRecipe(from draft: RecipeDraft) {
        // Check for duplicate URL
        let existingRecipe = recipes.first { $0.sourceURL == draft.sourceURL }
        
        if let existing = existingRecipe {
            // Update existing recipe instead of creating duplicate
            existing.title = draft.title
            existing.imageURL = draft.imageURL
            existing.servings = draft.servings
            existing.totalTime = draft.totalTime
            existing.ingredients = draft.ingredients
            existing.instructions = draft.instructions
            existing.notes = draft.notes
            existing.rawHTML = draft.rawHTML
            existing.updatedAt = Date()
        } else {
            // Create new recipe
            let recipe = Recipe(from: draft)
            modelContext.insert(recipe)
        }
        
        // Explicitly save
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistenceError("Failed to save recipe", error: error)
        }
        
        // Reset state
        showingExtraction = false
        extractionDraft = nil
        urlInput = ""
    }
    
    private func discardDraft() {
        showingExtraction = false
        extractionDraft = nil
    }
    
    private func createBlankDraft() {
        extractionDraft = RecipeDraft.blank(from: urlInput)
        showingExtraction = true
    }
    
    private func deleteRecipes(at offsets: IndexSet) {
        for index in offsets {
            let recipe = filteredRecipes[index]
            modelContext.delete(recipe)
        }
        
        // Explicitly save deletion
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistenceError("Failed to delete recipe", error: error)
        }
    }
}

// MARK: - Sort Order

enum SortOrder: String, CaseIterable, Identifiable {
    case mostRecent = "recent"
    case alphabetical = "alpha"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mostRecent: return "Most Recent"
        case .alphabetical: return "A-Z"
        }
    }
}

// MARK: - Recipe Row

struct RecipeRowView: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(recipe.title)
                .font(.headline)
                .lineLimit(2)
            
            HStack(spacing: 8) {
                Text(recipe.sourceDomain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let time = recipe.totalTime {
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text(time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recipe.title), from \(recipe.sourceDomain)")
    }
}

// MARK: - Preview

#Preview {
    HomeLibraryView()
        .modelContainer(PersistenceController.preview.container)
}
