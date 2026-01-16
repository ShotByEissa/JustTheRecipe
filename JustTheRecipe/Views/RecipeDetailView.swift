import SwiftUI
import SwiftData

// MARK: - Recipe Detail View
// Shows a saved recipe with option to enter cooking mode or edit.

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var recipe: Recipe
    
    @State private var showingCookingMode: Bool = false
    @State private var showingEditSheet: Bool = false
    @State private var showingDeleteConfirmation: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                Divider()
                
                // Ingredients
                ingredientsSection
                
                Divider()
                
                // Instructions
                instructionsSection
                
                // Notes (if any)
                if let notes = recipe.notes, !notes.isEmpty {
                    Divider()
                    notesSection(notes)
                }
                
                // Source link
                Divider()
                sourceSection
            }
            .padding()
        }
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingCookingMode = true }) {
                        Label("Start Cooking", systemImage: "flame")
                    }
                    .disabled(recipe.instructions.isEmpty)
                    
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit Recipe", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        Label("Delete Recipe", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Recipe actions")
                }
            }
            
            ToolbarItem(placement: .bottomBar) {
                Button(action: { showingCookingMode = true }) {
                    Label("Start Cooking", systemImage: "flame")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(recipe.instructions.isEmpty)
            }
        }
        .fullScreenCover(isPresented: $showingCookingMode) {
            NavigationStack {
                CookingView(recipe: recipe)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") {
                                showingCookingMode = false
                            }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRecipeView(recipe: recipe)
        }
        .confirmationDialog(
            "Delete Recipe?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This cannot be undone.")
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recipe.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            
            // Metadata chips
            if recipe.servings != nil || recipe.totalTime != nil {
                HStack(spacing: 12) {
                    if let servings = recipe.servings {
                        MetadataChip(icon: "person.2", text: servings)
                    }
                    if let time = recipe.totalTime {
                        MetadataChip(icon: "clock", text: time)
                    }
                }
            }
        }
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            if recipe.ingredients.isEmpty {
                Text("No ingredients listed")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(ingredient)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            if recipe.instructions.isEmpty {
                Text("No instructions listed")
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            
                            Text(instruction)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Step \(index + 1): \(instruction)")
                    }
                }
            }
        }
    }
    
    // MARK: - Notes Section
    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text(notes)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Source Section
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Source")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            if let url = recipe.sourceURLValue {
                Link(destination: url) {
                    HStack {
                        Text(recipe.sourceDomain)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                }
                .accessibilityLabel("Open original recipe on \(recipe.sourceDomain)")
            } else {
                Text(recipe.sourceDomain)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Actions
    private func deleteRecipe() {
        modelContext.delete(recipe)
        
        // Explicitly save deletion
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistenceError("Failed to delete recipe", error: error)
        }
        
        dismiss()
    }
}

// MARK: - Metadata Chip

struct MetadataChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.fill.tertiary)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            title: "Classic Chocolate Chip Cookies",
            sourceURL: "https://example.com/cookies",
            sourceDomain: "example.com",
            servings: "24 cookies",
            totalTime: "45 minutes",
            ingredients: [
                "2 cups all-purpose flour",
                "1 tsp baking soda",
                "1 tsp salt",
                "1 cup butter, softened",
                "3/4 cup granulated sugar",
                "3/4 cup packed brown sugar",
                "2 large eggs",
                "2 tsp vanilla extract",
                "2 cups chocolate chips"
            ],
            instructions: [
                "Preheat oven to 375°F.",
                "Mix flour, baking soda, and salt in a bowl.",
                "Beat butter with both sugars until creamy.",
                "Add eggs and vanilla to butter mixture.",
                "Gradually blend in flour mixture.",
                "Stir in chocolate chips.",
                "Drop rounded tablespoons onto ungreased baking sheets.",
                "Bake 9 to 11 minutes or until golden brown.",
                "Cool on baking sheets for 2 minutes.",
                "Remove to wire racks to cool completely."
            ],
            notes: "For softer cookies, reduce baking time by 1-2 minutes."
        ))
    }
    .modelContainer(PersistenceController.preview.container)
}
