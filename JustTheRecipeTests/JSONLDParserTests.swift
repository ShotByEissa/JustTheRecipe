import XCTest
@testable import JustTheRecipe

final class JSONLDParserTests: XCTestCase {
    
    // MARK: - Standard JSON-LD Tests
    
    func testParseStandardJSONLD() throws {
        let html = loadFixture("recipe_standard_jsonld")
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse standard JSON-LD recipe")
        XCTAssertEqual(draft?.title, "Classic Chocolate Chip Cookies")
        XCTAssertEqual(draft?.servings, "24 cookies")
        XCTAssertEqual(draft?.totalTime, "27 min")
        XCTAssertEqual(draft?.ingredients.count, 9)
        XCTAssertEqual(draft?.instructions.count, 9)
        XCTAssertEqual(draft?.extractionConfidence, .jsonLD)
        
        // Check first ingredient
        XCTAssertEqual(draft?.ingredients.first, "2 1/4 cups all-purpose flour")
        
        // Check instruction doesn't have step prefix
        XCTAssertEqual(draft?.instructions.first, "Preheat oven to 375°F.")
    }
    
    // MARK: - @graph Structure Tests
    
    func testParseGraphJSONLD() throws {
        let html = loadFixture("recipe_graph_jsonld")
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse @graph JSON-LD recipe")
        XCTAssertEqual(draft?.title, "Easy Pasta Primavera")
        XCTAssertEqual(draft?.totalTime, "30 min")
        XCTAssertEqual(draft?.ingredients.count, 9)
        XCTAssertEqual(draft?.instructions.count, 8)
        
        // Check that array yield takes first value
        XCTAssertEqual(draft?.servings, "4 servings")
        
        // Check that array image takes first value
        XCTAssertEqual(draft?.imageURL, "https://foodblog.example.com/images/pasta-1x1.jpg")
    }
    
    // MARK: - Array JSON-LD Tests
    
    func testParseArrayJSONLD() throws {
        let html = loadFixture("recipe_array_jsonld")
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse array JSON-LD and find recipe")
        XCTAssertEqual(draft?.title, "Simple Tomato Soup")
        XCTAssertEqual(draft?.totalTime, "35 min")
        XCTAssertEqual(draft?.ingredients.count, 9)
        
        // String instructions should be split
        XCTAssertEqual(draft?.instructions.count, 8)
        
        // Check step prefix removal from string instructions
        XCTAssertEqual(draft?.instructions.first, "Melt butter in a large pot over medium heat.")
    }
    
    // MARK: - Edge Cases
    
    func testNoJSONLD() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>No Recipe</title></head>
        <body><p>Just a regular page</p></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNil(draft, "Should return nil when no JSON-LD present")
    }
    
    func testJSONLDWithoutRecipe() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org",
                "@type": "Article",
                "name": "How to Cook",
                "author": "Chef"
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNil(draft, "Should return nil when JSON-LD has no Recipe type")
    }
    
    func testMalformedJSON() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Test Recipe",
                "recipeIngredient": ["flour", "sugar",],
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        // Should handle trailing commas
        XCTAssertNotNil(draft, "Should handle malformed JSON with trailing commas")
        XCTAssertEqual(draft?.title, "Test Recipe")
    }
    
    func testRecipeWithMinimalData() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Minimal Recipe"
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse recipe with only name")
        XCTAssertEqual(draft?.title, "Minimal Recipe")
        XCTAssertTrue(draft?.ingredients.isEmpty ?? false)
        XCTAssertTrue(draft?.instructions.isEmpty ?? false)
    }
    
    func testMultipleRecipesSelectsBest() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            [
                {
                    "@type": "Recipe",
                    "name": "Incomplete Recipe"
                },
                {
                    "@type": "Recipe",
                    "name": "Complete Recipe",
                    "recipeIngredient": ["ingredient 1", "ingredient 2"],
                    "recipeInstructions": ["step 1", "step 2"]
                }
            ]
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.title, "Complete Recipe", "Should select most complete recipe")
    }
    
    // MARK: - ISO Duration Tests
    
    func testISODurationParsing() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": "Recipe",
                "name": "Timed Recipe",
                "prepTime": "PT1H30M",
                "cookTime": "PT45M",
                "totalTime": "PT2H15M"
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.totalTime, "2 hours 15 min")
    }
    
    // MARK: - Type Array Tests
    
    func testTypeAsArray() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@type": ["Recipe", "HowTo"],
                "name": "Multi-type Recipe",
                "recipeIngredient": ["test ingredient"]
            }
            </script>
        </head>
        <body></body>
        </html>
        """
        
        let draft = JSONLDParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should handle @type as array")
        XCTAssertEqual(draft?.title, "Multi-type Recipe")
    }
    
    // MARK: - Helper Methods
    
    private func loadFixture(_ name: String) -> String {
        // In test bundle, fixtures would be loaded from bundle
        // For now, use inline fixtures based on name
        switch name {
        case "recipe_standard_jsonld":
            return standardJSONLDFixture
        case "recipe_graph_jsonld":
            return graphJSONLDFixture
        case "recipe_array_jsonld":
            return arrayJSONLDFixture
        default:
            return ""
        }
    }
    
    // Inline fixtures for testing without bundle
    private var standardJSONLDFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org",
                "@type": "Recipe",
                "name": "Classic Chocolate Chip Cookies",
                "image": "https://example.com/images/cookies.jpg",
                "totalTime": "PT27M",
                "recipeYield": "24 cookies",
                "recipeIngredient": [
                    "2 1/4 cups all-purpose flour",
                    "1 teaspoon baking soda",
                    "1 teaspoon salt",
                    "1 cup (2 sticks) butter, softened",
                    "3/4 cup granulated sugar",
                    "3/4 cup packed brown sugar",
                    "2 large eggs",
                    "1 teaspoon vanilla extract",
                    "2 cups chocolate chips"
                ],
                "recipeInstructions": [
                    {"@type": "HowToStep", "text": "Preheat oven to 375°F."},
                    {"@type": "HowToStep", "text": "Combine flour, baking soda and salt in small bowl."},
                    {"@type": "HowToStep", "text": "Beat butter, granulated sugar, brown sugar and vanilla extract in large mixer bowl until creamy."},
                    {"@type": "HowToStep", "text": "Add eggs, one at a time, beating well after each addition."},
                    {"@type": "HowToStep", "text": "Gradually beat in flour mixture."},
                    {"@type": "HowToStep", "text": "Stir in chocolate chips."},
                    {"@type": "HowToStep", "text": "Drop rounded tablespoon of dough onto ungreased baking sheets."},
                    {"@type": "HowToStep", "text": "Bake for 9 to 11 minutes or until golden brown."},
                    {"@type": "HowToStep", "text": "Cool on baking sheets for 2 minutes; remove to wire racks to cool completely."}
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """
    }
    
    private var graphJSONLDFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            {
                "@context": "https://schema.org",
                "@graph": [
                    {"@type": "WebSite", "name": "Food Blog"},
                    {
                        "@type": "Recipe",
                        "name": "Easy Pasta Primavera",
                        "totalTime": "PT30M",
                        "recipeYield": ["4 servings", "4"],
                        "image": [
                            "https://foodblog.example.com/images/pasta-1x1.jpg",
                            "https://foodblog.example.com/images/pasta-4x3.jpg"
                        ],
                        "recipeIngredient": [
                            "1 pound penne pasta",
                            "2 tablespoons olive oil",
                            "3 cloves garlic, minced",
                            "1 cup cherry tomatoes, halved",
                            "1 cup zucchini, diced",
                            "1 cup bell peppers, sliced",
                            "1/2 cup fresh basil, chopped",
                            "1/4 cup parmesan cheese, grated",
                            "Salt and pepper to taste"
                        ],
                        "recipeInstructions": [
                            "Cook pasta according to package directions.",
                            "Heat olive oil in a large skillet.",
                            "Add garlic and cook for 30 seconds.",
                            "Add zucchini and bell peppers.",
                            "Add cherry tomatoes and cook.",
                            "Toss in the drained pasta.",
                            "Stir in fresh basil and parmesan.",
                            "Season and serve."
                        ]
                    }
                ]
            }
            </script>
        </head>
        <body></body>
        </html>
        """
    }
    
    private var arrayJSONLDFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <script type="application/ld+json">
            [
                {"@type": "BreadcrumbList", "itemListElement": []},
                {
                    "@type": "Recipe",
                    "name": "Simple Tomato Soup",
                    "totalTime": "PT35M",
                    "recipeYield": "6 servings",
                    "recipeIngredient": [
                        "2 cans whole peeled tomatoes",
                        "1 medium onion, diced",
                        "4 cloves garlic, minced",
                        "2 cups vegetable broth",
                        "2 tablespoons butter",
                        "1 teaspoon sugar",
                        "1/2 cup heavy cream",
                        "Fresh basil for garnish",
                        "Salt and pepper to taste"
                    ],
                    "recipeInstructions": "1. Melt butter in a large pot.\\n2. Add onion and cook until softened.\\n3. Add garlic and cook for 1 minute.\\n4. Pour in tomatoes and broth.\\n5. Bring to a boil, then simmer.\\n6. Blend until smooth.\\n7. Stir in heavy cream.\\n8. Serve hot with basil."
                }
            ]
            </script>
        </head>
        <body></body>
        </html>
        """
    }
}
