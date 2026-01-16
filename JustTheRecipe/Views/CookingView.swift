import SwiftUI

// MARK: - Cooking View
// Distraction-free view for following a recipe while cooking.
// Large typography, step highlighting, optional screen awake.

struct CookingView: View {
    let recipe: Recipe
    
    @State private var currentStep: Int = 0
    @State private var keepAwake: Bool = true // Default ON for cooking
    @State private var completedSteps: Set<Int> = []
    @State private var showingIngredients: Bool = true
    
    /// Safe instruction count (minimum 1 to avoid division by zero)
    private var stepCount: Int {
        max(recipe.instructions.count, 1)
    }
    
    /// Safe current step (clamped to valid range)
    private var safeCurrentStep: Int {
        min(currentStep, max(recipe.instructions.count - 1, 0))
    }
    
    var body: some View {
        Group {
            if recipe.instructions.isEmpty {
                // Empty state for recipes without instructions
                ContentUnavailableView(
                    "No Instructions",
                    systemImage: "list.bullet.clipboard",
                    description: Text("This recipe doesn't have any instructions. Edit the recipe to add some.")
                )
            } else {
                cookingContent
            }
        }
        .navigationTitle("Cooking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $keepAwake) {
                    Image(systemName: keepAwake ? "sun.max.fill" : "sun.max")
                }
                .toggleStyle(.button)
                .accessibilityLabel(keepAwake ? "Screen stays on" : "Screen will turn off")
                .accessibilityHint("Toggle to keep screen awake while cooking")
            }
        }
        .onChange(of: keepAwake) { _, newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepAwake
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
    
    // MARK: - Main Cooking Content
    private var cookingContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    headerSection
                    
                    // Ingredients (collapsible)
                    ingredientsSection
                    
                    // Instructions
                    instructionsSection(proxy: proxy)
                    
                    // Bottom padding for toolbar
                    Spacer()
                        .frame(height: 80)
                }
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            stepNavigationBar
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)
            
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
            }
        }
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { showingIngredients.toggle() } }) {
                HStack {
                    Text("Ingredients")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showingIngredients ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ingredients, \(showingIngredients ? "expanded" : "collapsed")")
            .accessibilityHint("Double tap to \(showingIngredients ? "collapse" : "expand")")
            
            if showingIngredients {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(recipe.ingredients, id: \.self) { ingredient in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                            
                            Text(ingredient)
                                .font(.body)
                        }
                    }
                }
                .padding(.leading, 4)
            }
            
            Divider()
        }
    }
    
    // MARK: - Instructions Section
    private func instructionsSection(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                stepRow(index: index, instruction: instruction)
                    .id(index)
            }
        }
    }
    
    // MARK: - Step Row
    private func stepRow(index: Int, instruction: String) -> some View {
        let isCurrentStep = index == currentStep
        let isCompleted = completedSteps.contains(index)
        
        return Button(action: { selectStep(index) }) {
            HStack(alignment: .top, spacing: 16) {
                // Step number / checkmark
                ZStack {
                    Circle()
                        .fill(stepCircleColor(index: index))
                        .frame(width: 36, height: 36)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(index + 1)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(isCurrentStep ? .white : .primary)
                    }
                }
                
                // Instruction text
                Text(instruction)
                    .font(.title3)
                    .fontWeight(isCurrentStep ? .medium : .regular)
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrentStep ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrentStep ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(index + 1)\(isCompleted ? ", completed" : ""): \(instruction)")
        .accessibilityHint(isCurrentStep ? "Current step. Double tap to mark complete" : "Double tap to go to this step")
        .accessibilityAddTraits(isCurrentStep ? .isSelected : [])
    }
    
    private func stepCircleColor(index: Int) -> Color {
        if completedSteps.contains(index) {
            return .green
        } else if index == currentStep {
            return .accentColor
        } else {
            return .fill.tertiary
        }
    }
    
    // MARK: - Step Navigation Bar
    private var stepNavigationBar: some View {
        HStack(spacing: 20) {
            Button(action: previousStep) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .disabled(currentStep == 0)
            .accessibilityLabel("Previous step")
            
            // Progress indicator
            VStack(spacing: 4) {
                Text("Step \(safeCurrentStep + 1) of \(stepCount)")
                    .font(.headline)
                
                ProgressView(value: Double(completedSteps.count), total: Double(stepCount))
                    .frame(width: 120)
            }
            
            Button(action: nextStep) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .frame(width: 44, height: 44)
            }
            .disabled(currentStep >= recipe.instructions.count - 1)
            .accessibilityLabel("Next step")
        }
        .padding()
        .background(.regularMaterial)
    }
    
    // MARK: - Actions
    
    private func selectStep(_ index: Int) {
        if index == currentStep {
            // Toggle completion on current step
            if completedSteps.contains(index) {
                completedSteps.remove(index)
            } else {
                completedSteps.insert(index)
            }
        } else {
            // Jump to step
            withAnimation {
                currentStep = index
            }
        }
    }
    
    private func previousStep() {
        guard currentStep > 0 else { return }
        withAnimation {
            currentStep -= 1
        }
    }
    
    private func nextStep() {
        // Mark current as complete before moving
        completedSteps.insert(currentStep)
        
        guard currentStep < recipe.instructions.count - 1 else { return }
        withAnimation {
            currentStep += 1
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
                "2 cans (14 oz each) crushed tomatoes",
                "4 cloves garlic, minced",
                "1/4 cup extra virgin olive oil",
                "1/2 cup fresh basil leaves",
                "1 tsp salt",
                "1/2 tsp black pepper",
                "1/4 tsp red pepper flakes (optional)",
                "Parmesan cheese for serving"
            ],
            instructions: [
                "Bring a large pot of salted water to a rolling boil.",
                "Add pasta and cook according to package directions until al dente.",
                "Meanwhile, heat olive oil in a large skillet over medium heat.",
                "Add minced garlic and cook until fragrant, about 1 minute. Don't let it brown.",
                "Pour in crushed tomatoes, salt, pepper, and red pepper flakes if using.",
                "Let the sauce simmer for 15-20 minutes, stirring occasionally.",
                "Reserve 1 cup of pasta water before draining.",
                "Drain pasta and add directly to the sauce.",
                "Toss pasta with sauce, adding pasta water as needed for consistency.",
                "Remove from heat and stir in fresh basil.",
                "Serve immediately with grated Parmesan cheese."
            ]
        ))
    }
}
