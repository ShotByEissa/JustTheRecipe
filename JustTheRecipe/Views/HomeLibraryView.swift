import SwiftUI
import SwiftData

// MARK: - Home / Library View
// Main view showing URL input and saved recipes.
// TODO: Phase 2 - Full implementation with search, filter, sort

struct HomeLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.updatedAt, order: .reverse) private var recipes: [Recipe]
    
    var body: some View {
        NavigationStack {
            List {
                // URL Input Section
                Section {
                    Text("Paste a recipe URL to extract")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Add Recipe")
                }
                
                // Saved Recipes Section
                Section {
                    if recipes.isEmpty {
                        ContentUnavailableView(
                            "No Recipes Yet",
                            systemImage: "book.closed",
                            description: Text("Paste a recipe URL above to get started.")
                        )
                    } else {
                        ForEach(recipes) { recipe in
                            RecipeRowView(recipe: recipe)
                        }
                    }
                } header: {
                    Text("Your Recipes")
                }
            }
            .navigationTitle("JustTheRecipe")
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
            
            Text(recipe.sourceDomain)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    HomeLibraryView()
        .modelContainer(PersistenceController.preview.container)
}
