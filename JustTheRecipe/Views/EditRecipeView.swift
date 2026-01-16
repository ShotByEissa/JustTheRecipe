import SwiftUI
import SwiftData

// MARK: - Edit Recipe View
// Allows editing an already-saved recipe.

struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var recipe: Recipe
    
    // Local editing state to allow cancel
    @State private var editTitle: String = ""
    @State private var editServings: String = ""
    @State private var editTotalTime: String = ""
    @State private var editIngredients: [String] = []
    @State private var editInstructions: [String] = []
    @State private var editNotes: String = ""
    
    @State private var showingDiscardConfirmation: Bool = false
    
    private var hasChanges: Bool {
        editTitle != recipe.title ||
        editServings != (recipe.servings ?? "") ||
        editTotalTime != (recipe.totalTime ?? "") ||
        editIngredients != recipe.ingredients ||
        editInstructions != recipe.instructions ||
        editNotes != (recipe.notes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section("Title") {
                    TextField("Recipe Title", text: $editTitle)
                        .accessibilityLabel("Recipe title")
                }
                
                // Details Section
                Section("Details") {
                    TextField("Servings (e.g., 4 servings)", text: $editServings)
                        .accessibilityLabel("Number of servings")
                    TextField("Total Time (e.g., 30 minutes)", text: $editTotalTime)
                        .accessibilityLabel("Total cooking time")
                }
                
                // Ingredients Section
                Section {
                    EditableListSection(
                        items: $editIngredients,
                        placeholder: "Add ingredient"
                    )
                } header: {
                    Text("Ingredients (\(editIngredients.count))")
                }
                
                // Instructions Section
                Section {
                    EditableListSection(
                        items: $editInstructions,
                        placeholder: "Add step",
                        showNumbers: true
                    )
                } header: {
                    Text("Instructions (\(editInstructions.count))")
                }
                
                // Notes Section
                Section("Notes") {
                    TextField("Optional notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .accessibilityLabel("Recipe notes")
                }
            }
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog(
                "Discard Changes?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) { }
            }
            .onAppear {
                loadRecipeData()
            }
        }
    }
    
    private func loadRecipeData() {
        editTitle = recipe.title
        editServings = recipe.servings ?? ""
        editTotalTime = recipe.totalTime ?? ""
        editIngredients = recipe.ingredients
        editInstructions = recipe.instructions
        editNotes = recipe.notes ?? ""
    }
    
    private func saveChanges() {
        recipe.title = editTitle.trimmingCharacters(in: .whitespaces)
        recipe.servings = editServings.isEmpty ? nil : editServings
        recipe.totalTime = editTotalTime.isEmpty ? nil : editTotalTime
        recipe.ingredients = editIngredients.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        recipe.instructions = editInstructions.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        recipe.notes = editNotes.isEmpty ? nil : editNotes
        recipe.updatedAt = Date()
        
        // Explicitly save changes
        do {
            try modelContext.save()
        } catch {
            AppLogger.persistenceError("Failed to save recipe changes", error: error)
        }
        
        dismiss()
    }
}

// MARK: - Editable List Section
// Reusable component for editing lists of strings with add/remove/reorder.

struct EditableListSection: View {
    @Binding var items: [String]
    let placeholder: String
    var showNumbers: Bool = false
    
    @State private var newItemText: String = ""
    
    var body: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            HStack {
                if showNumbers {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .leading)
                }
                
                TextField("Item", text: Binding(
                    get: { items[index] },
                    set: { items[index] = $0 }
                ))
            }
            .accessibilityLabel(showNumbers ? "Step \(index + 1)" : "Item \(index + 1)")
        }
        .onDelete(perform: deleteItems)
        .onMove(perform: moveItems)
        
        // Add new item row
        HStack {
            if showNumbers {
                Text("\(items.count + 1).")
                    .foregroundStyle(.tertiary)
                    .frame(width: 30, alignment: .leading)
            }
            
            TextField(placeholder, text: $newItemText)
                .onSubmit {
                    addNewItem()
                }
            
            if !newItemText.isEmpty {
                Button(action: addNewItem) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add item")
            }
        }
        .foregroundStyle(.secondary)
    }
    
    private func addNewItem() {
        let trimmed = newItemText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        items.append(trimmed)
        newItemText = ""
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Preview

#Preview {
    EditRecipeView(recipe: Recipe(
        title: "Test Recipe",
        sourceURL: "https://example.com",
        sourceDomain: "example.com",
        ingredients: ["1 cup flour", "2 eggs"],
        instructions: ["Mix", "Bake"]
    ))
    .modelContainer(PersistenceController.preview.container)
}
