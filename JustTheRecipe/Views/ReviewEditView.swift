import SwiftUI

// MARK: - Review & Edit View
// Shows extracted recipe for review and editing before save.
// TODO: Phase 2 - Full implementation

struct ReviewEditView: View {
    @Bindable var draft: RecipeDraft
    var onSave: () -> Void
    var onDiscard: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Recipe Title", text: $draft.title)
                }
                
                Section("Details") {
                    TextField("Servings", text: Binding(
                        get: { draft.servings ?? "" },
                        set: { draft.servings = $0.isEmpty ? nil : $0 }
                    ))
                    TextField("Total Time", text: Binding(
                        get: { draft.totalTime ?? "" },
                        set: { draft.totalTime = $0.isEmpty ? nil : $0 }
                    ))
                }
                
                Section("Ingredients") {
                    if draft.ingredients.isEmpty {
                        Text("No ingredients extracted")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draft.ingredients.indices, id: \.self) { index in
                            Text(draft.ingredients[index])
                        }
                    }
                }
                
                Section("Instructions") {
                    if draft.instructions.isEmpty {
                        Text("No instructions extracted")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(draft.instructions.indices, id: \.self) { index in
                            Text("\(index + 1). \(draft.instructions[index])")
                        }
                    }
                }
            }
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        onDiscard()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(!draft.isValid)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let draft = RecipeDraft(
        title: "Test Recipe",
        sourceURL: "https://example.com/recipe",
        sourceDomain: "example.com",
        ingredients: ["1 cup flour", "2 eggs", "1 cup milk"],
        instructions: ["Mix ingredients", "Cook until done"]
    )
    
    return ReviewEditView(
        draft: draft,
        onSave: {},
        onDiscard: {}
    )
}
