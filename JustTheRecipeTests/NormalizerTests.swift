import XCTest
@testable import JustTheRecipe

final class NormalizerTests: XCTestCase {
    
    let normalizer = RuleBasedNormalizer()
    
    // MARK: - Title Normalization Tests
    
    func testNormalizeTitleRemovesSuffix() async throws {
        let draft = RecipeDraft(
            title: "Chocolate Cake | My Food Blog",
            ingredients: ["flour"],
            instructions: ["Mix ingredients"]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.title, "Chocolate Cake")
    }
    
    func testNormalizeTitleRemovesRecipeSuffix() async throws {
        let draft = RecipeDraft(
            title: "Chocolate Cake Recipe",
            ingredients: ["flour"],
            instructions: ["Mix ingredients"]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.title, "Chocolate Cake")
    }
    
    func testNormalizeTitleCapitalizesAllCaps() async throws {
        let draft = RecipeDraft(
            title: "CHOCOLATE CAKE",
            ingredients: ["flour"],
            instructions: ["Mix ingredients"]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.title, "Chocolate Cake")
    }
    
    // MARK: - Ingredient Normalization Tests
    
    func testNormalizeIngredientsRemovesBullets() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [
                "• 1 cup flour",
                "- 2 eggs",
                "* 1 cup sugar"
            ],
            instructions: ["Mix ingredients together."]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.ingredients[0], "1 cup flour")
        XCTAssertEqual(normalized.ingredients[1], "2 eggs")
        XCTAssertEqual(normalized.ingredients[2], "1 cup sugar")
    }
    
    func testNormalizeIngredientsRemovesDuplicates() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [
                "1 cup flour",
                "1 cup flour",  // Exact duplicate
                "1 Cup Flour",  // Case-insensitive duplicate
                "2 eggs"
            ],
            instructions: ["Mix ingredients together."]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.ingredients.count, 2)
        XCTAssertEqual(normalized.ingredients[0], "1 cup flour")
        XCTAssertEqual(normalized.ingredients[1], "2 eggs")
    }
    
    func testNormalizeIngredientsRemovesSectionHeaders() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [
                "For the cake:",
                "1 cup flour",
                "Ingredients:",
                "2 eggs",
                "Optional:",
                "chocolate chips"
            ],
            instructions: ["Mix ingredients together."]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        // Should only have actual ingredients
        XCTAssertFalse(normalized.ingredients.contains("For the cake:"))
        XCTAssertFalse(normalized.ingredients.contains("Ingredients:"))
        XCTAssertFalse(normalized.ingredients.contains("Optional:"))
        XCTAssertTrue(normalized.ingredients.contains("1 cup flour"))
        XCTAssertTrue(normalized.ingredients.contains("2 eggs"))
    }
    
    func testNormalizeIngredientsFractions() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [
                "1/2 cup butter",
                "1/4 teaspoon salt",
                "3/4 cup sugar"
            ],
            instructions: ["Mix ingredients together."]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.ingredients[0], "½ cup butter")
        XCTAssertEqual(normalized.ingredients[1], "¼ teaspoon salt")
        XCTAssertEqual(normalized.ingredients[2], "¾ cup sugar")
    }
    
    func testNormalizeIngredientsFiltersShortItems() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [
                "a",  // Too short
                "1 cup flour",
                "",   // Empty
                "2 eggs"
            ],
            instructions: ["Mix ingredients together."]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.ingredients.count, 2)
    }
    
    // MARK: - Instruction Normalization Tests
    
    func testNormalizeInstructionsRemovesStepPrefixes() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: [
                "Step 1: Preheat the oven to 350°F",
                "Step 2. Mix the ingredients",
                "3) Pour into pan",
                "4- Bake for 30 minutes"
            ]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.instructions[0], "Preheat the oven to 350°F.")
        XCTAssertEqual(normalized.instructions[1], "Mix the ingredients.")
        XCTAssertEqual(normalized.instructions[2], "Pour into pan.")
        XCTAssertEqual(normalized.instructions[3], "Bake for 30 minutes.")
    }
    
    func testNormalizeInstructionsAddsPeriod() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: [
                "Mix the flour and sugar",
                "Add eggs and mix well.",
                "Bake until golden!"
            ]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertTrue(normalized.instructions[0].hasSuffix("."))
        XCTAssertTrue(normalized.instructions[1].hasSuffix("."))
        XCTAssertTrue(normalized.instructions[2].hasSuffix("!"))  // Keep existing punctuation
    }
    
    func testNormalizeInstructionsRemovesFluff() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: [
                "Mix the ingredients together.",
                "Advertisement",
                "Share this recipe",
                "Bake for 30 minutes.",
                "Leave a comment below",
                "Let cool before serving."
            ]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.instructions.count, 3)
        XCTAssertFalse(normalized.instructions.contains { $0.lowercased().contains("advertisement") })
        XCTAssertFalse(normalized.instructions.contains { $0.lowercased().contains("share") })
        XCTAssertFalse(normalized.instructions.contains { $0.lowercased().contains("comment") })
    }
    
    func testNormalizeInstructionsRemovesDuplicates() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: [
                "Preheat oven to 350°F.",
                "Mix all ingredients.",
                "Preheat oven to 350°F.",  // Duplicate
                "Bake for 30 minutes."
            ]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.instructions.count, 3)
    }
    
    func testNormalizeInstructionsCapitalizesFirst() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: [
                "mix the ingredients together well"
            ]
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertTrue(normalized.instructions[0].first?.isUppercase ?? false)
    }
    
    // MARK: - Metadata Normalization Tests
    
    func testNormalizeServings() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: ["Mix ingredients."],
            servings: "Serves: 8"
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.servings, "8 servings")
    }
    
    func testNormalizeServingsPlainNumber() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: ["Mix ingredients."],
            servings: "4"
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.servings, "4 servings")
    }
    
    func testNormalizeTime() async throws {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: ["Mix ingredients."],
            totalTime: "Total Time: 45 mins"
        )
        
        let normalized = try await normalizer.normalize(draft: draft)
        
        XCTAssertEqual(normalized.totalTime, "45 min")
    }
    
    // MARK: - Apple Intelligence Availability
    
    func testAppleIntelligenceNotAvailable() {
        XCTAssertFalse(AppleIntelligenceNormalizer.isAvailable)
    }
    
    func testNormalizationServiceUsesRuleBased() async {
        let type = await NormalizationService.shared.normalizerType
        XCTAssertEqual(type, .ruleBased)
    }
}
