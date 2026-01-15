import SwiftUI

// MARK: - Cooking View
// Distraction-free view for following a recipe while cooking.
// TODO: Phase 2 - Full implementation with step highlighting, keep awake

struct CookingView: View {
    let recipe: Recipe
    
    @State private var currentStep: Int = 0
    @State private var keepAwake: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text(recipe.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.horizontal)
                
                // Metadata
                if recipe.servings != nil || recipe.totalTime != nil {
                    HStack(spacing: 16) {
                        if let servings = recipe.servings {
                            Label(servings, systemImage: "person.2")
                        }
                        if let time = recipe.totalTime {
                            Label(time, systemImage: "clock")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Ingredients
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        Text("• \(ingredient)")
                            .font(.body)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    ForEach(recipe.instructions.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.headline)
                                .foregroundStyle(index == currentStep ? .primary : .secondary)
                                .frame(width: 30, alignment: .leading)
                            
                            Text(recipe.instructions[index])
                                .font(.body)
                                .fontWeight(index == currentStep ? .medium : .regular)
                        }
                        .padding(.vertical, 8)
                        .background(
                            index == currentStep ?
                            Color.accentColor.opacity(0.1) :
                            Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            withAnimation {
                                currentStep = index
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Cooking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $keepAwake) {
                    Label("Keep Awake", systemImage: keepAwake ? "sun.max.fill" : "sun.max")
                }
                .toggleStyle(.button)
            }
        }
        .onChange(of: keepAwake) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CookingView(recipe: Recipe(
            title: "Classic Tomato Pasta",
            sourceURL: "https://example.com/pasta",
            sourceDomain: "example.com",
            servings: "4 servings",
            totalTime: "30 minutes",
            ingredients: [
                "1 lb spaghetti",
                "2 cans crushed tomatoes",
                "4 cloves garlic, minced",
                "1/4 cup olive oil",
                "Fresh basil",
                "Salt and pepper to taste"
            ],
            instructions: [
                "Bring a large pot of salted water to boil.",
                "Cook pasta according to package directions.",
                "Meanwhile, heat olive oil in a large skillet over medium heat.",
                "Add garlic and cook until fragrant, about 1 minute.",
                "Add crushed tomatoes, salt, and pepper. Simmer 15 minutes.",
                "Drain pasta and toss with sauce.",
                "Garnish with fresh basil and serve."
            ]
        ))
    }
}
