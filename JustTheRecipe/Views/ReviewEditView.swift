import SwiftUI

// MARK: - Review & Edit View
// Shows extracted recipe for review and editing before save.
// Presented as a sheet after extraction.

struct ReviewEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var draft: RecipeDraft
    var onSave: () -> Void
    var onDiscard: () -> Void
    
    @State private var showingDiscardConfirmation: Bool = false
    @State private var showingValidationAlert: Bool = false
    @State private var validationIssues: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // Extraction confidence banner
                if draft.extractionConfidence != .manual {
                    Section {
                        ExtractionConfidenceBanner(confidence: draft.extractionConfidence)
                    }
                }
                
                // Validation warning (if issues exist)
                if !validationIssues.isEmpty {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(validationIssues.first ?? "Please review the recipe")
                                .font(.subheadline)
                        }
                    }
                }
                
                // Title Section
                Section("Title") {
                    TextField("Recipe Title", text: $draft.title)
                        .font(.headline)
                        .accessibilityLabel("Recipe title")
                        .onChange(of: draft.title) { _, _ in revalidate() }
                }
                
                // Details Section
                Section("Details") {
                    TextField("Servings (e.g., 4 servings)", text: Binding(
                        get: { draft.servings ?? "" },
                        set: { draft.servings = $0.isEmpty ? nil : $0 }
                    ))
                    .accessibilityLabel("Number of servings")
                    
                    TextField("Total Time (e.g., 30 minutes)", text: Binding(
                        get: { draft.totalTime ?? "" },
                        set: { draft.totalTime = $0.isEmpty ? nil : $0 }
                    ))
                    .accessibilityLabel("Total cooking time")
                }
                
                // Ingredients Section
                Section {
                    EditableListSection(
                        items: $draft.ingredients,
                        placeholder: "Add ingredient"
                    )
                } header: {
                    HStack {
                        Text("Ingredients")
                        Spacer()
                        Text("\(draft.ingredients.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Instructions Section
                Section {
                    EditableListSection(
                        items: $draft.instructions,
                        placeholder: "Add step",
                        showNumbers: true
                    )
                } header: {
                    HStack {
                        Text("Instructions")
                        Spacer()
                        Text("\(draft.instructions.count)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Notes Section
                Section("Notes (Optional)") {
                    TextField("Add any notes", text: Binding(
                        get: { draft.notes ?? "" },
                        set: { draft.notes = $0.isEmpty ? nil : $0 }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityLabel("Recipe notes")
                }
                
                // Source info (read-only)
                if !draft.sourceURL.isEmpty {
                    Section("Source") {
                        LabeledContent("URL", value: draft.sourceDomain)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        showingDiscardConfirmation = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        validateAndSave()
                    }
                    .fontWeight(.semibold)
                    .disabled(!draft.isValid)
                }
            }
            .confirmationDialog(
                "Discard this recipe?",
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) {
                    onDiscard()
                }
                Button("Keep Editing", role: .cancel) { }
            } message: {
                Text("Your changes won't be saved.")
            }
            .alert("Cannot Save Recipe", isPresented: $showingValidationAlert) {
                Button("OK") { }
            } message: {
                Text(validationIssues.joined(separator: "\n"))
            }
            .interactiveDismissDisabled()
            .onAppear {
                revalidate()
            }
        }
    }
    
    // MARK: - Validation
    
    private func revalidate() {
        validationIssues = ContentValidator.validate(draft)
    }
    
    private func validateAndSave() {
        let issues = ContentValidator.validate(draft)
        
        if issues.isEmpty {
            onSave()
        } else {
            validationIssues = issues
            showingValidationAlert = true
        }
    }
}

// MARK: - Extraction Confidence Banner

struct ExtractionConfidenceBanner: View {
    let confidence: ExtractionConfidence
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
    
    private var iconName: String {
        switch confidence {
        case .jsonLD: return "checkmark.seal.fill"
        case .heuristic: return "wand.and.stars"
        case .manual: return "pencil"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch confidence {
        case .jsonLD: return .green
        case .heuristic: return .orange
        case .manual: return .blue
        case .unknown: return .gray
        }
    }
    
    private var title: String {
        switch confidence {
        case .jsonLD: return "High Confidence"
        case .heuristic: return "Extracted from Page"
        case .manual: return "Manual Entry"
        case .unknown: return "Unknown Source"
        }
    }
    
    private var subtitle: String {
        switch confidence {
        case .jsonLD: return "Found structured recipe data"
        case .heuristic: return "Review carefully - some cleanup may be needed"
        case .manual: return "Enter your recipe details below"
        case .unknown: return "Source could not be determined"
        }
    }
}

// MARK: - Preview

#Preview("With Mock Data") {
    let draft = RecipeDraft(
        title: "Chocolate Chip Cookies",
        sourceURL: "https://example.com/cookies",
        sourceDomain: "example.com",
        servings: "24 cookies",
        totalTime: "45 minutes",
        ingredients: [
            "2 cups flour",
            "1 cup butter",
            "1 cup sugar",
            "2 eggs",
            "1 tsp vanilla",
            "2 cups chocolate chips"
        ],
        instructions: [
            "Preheat oven to 375°F.",
            "Mix dry ingredients.",
            "Cream butter and sugar.",
            "Add eggs and vanilla.",
            "Combine wet and dry ingredients.",
            "Fold in chocolate chips.",
            "Bake for 10-12 minutes."
        ],
        extractionConfidence: .jsonLD
    )
    
    return ReviewEditView(
        draft: draft,
        onSave: {},
        onDiscard: {}
    )
}

#Preview("Heuristic Extraction") {
    let draft = RecipeDraft(
        title: "Pasta Recipe",
        sourceURL: "https://blog.example.com/pasta",
        sourceDomain: "blog.example.com",
        ingredients: ["pasta", "sauce"],
        instructions: ["Cook pasta", "Add sauce"],
        extractionConfidence: .heuristic
    )
    
    return ReviewEditView(
        draft: draft,
        onSave: {},
        onDiscard: {}
    )
}

#Preview("Blank/Manual") {
    return ReviewEditView(
        draft: RecipeDraft.blank(from: "https://example.com"),
        onSave: {},
        onDiscard: {}
    )
}
