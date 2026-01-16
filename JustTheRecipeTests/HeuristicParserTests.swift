import XCTest
@testable import JustTheRecipe

final class HeuristicParserTests: XCTestCase {
    
    // MARK: - Standard Structure Tests
    
    func testParseStandardStructure() throws {
        let html = standardFixture
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse standard HTML recipe")
        XCTAssertEqual(draft?.title, "Grandma's Apple Pie")
        XCTAssertEqual(draft?.extractionConfidence, .heuristic)
        XCTAssertEqual(draft?.ingredients.count, 10)
        XCTAssertEqual(draft?.instructions.count, 9)
        
        // Check first ingredient
        XCTAssertEqual(draft?.ingredients.first, "2 1/2 cups all-purpose flour")
        
        // Check instruction doesn't have step number
        XCTAssertTrue(draft?.instructions.first?.starts(with: "Combine") ?? false)
    }
    
    // MARK: - Class-Based Structure Tests
    
    func testParseClassBasedStructure() throws {
        let html = classBasedFixture
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse class-based HTML recipe")
        XCTAssertEqual(draft?.title, "Quick Banana Bread")
        XCTAssertEqual(draft?.ingredients.count, 8)
        XCTAssertEqual(draft?.instructions.count, 9)
        
        // Should extract og:image
        XCTAssertEqual(draft?.imageURL, "https://example.com/banana-bread.jpg")
    }
    
    // MARK: - Minimal Structure Tests
    
    func testParseMinimalStructure() throws {
        let html = minimalFixture
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should parse minimal HTML recipe")
        XCTAssertEqual(draft?.title, "Simple Scrambled Eggs")
        
        // Ingredients from <br> separated text
        XCTAssertGreaterThanOrEqual(draft?.ingredients.count ?? 0, 3)
        
        // Instructions from step-prefixed paragraphs
        XCTAssertEqual(draft?.instructions.count, 6)
    }
    
    // MARK: - Edge Cases
    
    func testNoRecipeContent() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>About Us</title></head>
        <body>
            <h1>About Our Company</h1>
            <p>We are a company that does things.</p>
            <p>Contact us for more information.</p>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNil(draft, "Should return nil for non-recipe pages")
    }
    
    func testStripsNavigationAndAds() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Recipe</title></head>
        <body>
            <nav>
                <ul>
                    <li>Home</li>
                    <li>Recipes</li>
                    <li>About</li>
                </ul>
            </nav>
            
            <h1>Test Recipe</h1>
            
            <h2>Ingredients</h2>
            <ul>
                <li>1 cup flour</li>
                <li>1 cup sugar</li>
            </ul>
            
            <aside class="advertisement">
                <p>Buy our cookbook!</p>
            </aside>
            
            <h2>Instructions</h2>
            <ol>
                <li>Mix the ingredients together in a large bowl.</li>
                <li>Bake at 350 degrees for 30 minutes.</li>
            </ol>
            
            <footer>
                <p>Copyright 2024</p>
            </footer>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.ingredients.count, 2)
        XCTAssertEqual(draft?.instructions.count, 2)
        
        // Nav items should not be in ingredients
        XCTAssertFalse(draft?.ingredients.contains("Home") ?? true)
        XCTAssertFalse(draft?.ingredients.contains("Recipes") ?? true)
    }
    
    func testHandlesHTMLEntities() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body>
            <h1>Fran&ccedil;ois&#39;s Recipe</h1>
            
            <h2>Ingredients</h2>
            <ul>
                <li>&frac12; cup butter</li>
                <li>&frac14; teaspoon salt</li>
                <li>350&deg;F oven</li>
            </ul>
            
            <h2>Instructions</h2>
            <ol>
                <li>Preheat the oven to 350&deg;F and prepare your ingredients.</li>
            </ol>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        
        // Check HTML entity decoding
        XCTAssertTrue(draft?.ingredients.contains("½ cup butter") ?? false)
        XCTAssertTrue(draft?.ingredients.contains("¼ teaspoon salt") ?? false)
    }
    
    func testExtractsServingsAndTime() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Recipe</title></head>
        <body>
            <h1>Test Recipe</h1>
            
            <p>Serves: 6 people</p>
            <p>Total Time: 45 minutes</p>
            
            <h2>Ingredients</h2>
            <ul>
                <li>1 cup water</li>
            </ul>
            
            <h2>Instructions</h2>
            <ol>
                <li>Boil the water and serve immediately to your guests.</li>
            </ol>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        XCTAssertEqual(draft?.servings, "6 people")
        XCTAssertEqual(draft?.totalTime, "45 minutes")
    }
    
    func testAlternativeHeadings() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Recipe</title></head>
        <body>
            <h1>Test Recipe</h1>
            
            <h3>What You'll Need</h3>
            <ul>
                <li>Flour</li>
                <li>Sugar</li>
            </ul>
            
            <h3>Directions</h3>
            <ol>
                <li>Mix everything together and bake until golden brown.</li>
            </ol>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft, "Should recognize alternative heading patterns")
        XCTAssertEqual(draft?.ingredients.count, 2)
        XCTAssertEqual(draft?.instructions.count, 1)
    }
    
    func testRemovesStepPrefixes() {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test</title></head>
        <body>
            <h1>Test</h1>
            
            <h2>Ingredients</h2>
            <ul><li>Test ingredient</li></ul>
            
            <h2>Instructions</h2>
            <ol>
                <li>Step 1: Do the first thing carefully.</li>
                <li>Step 2. Do the second thing.</li>
                <li>3) Do the third thing.</li>
                <li>4- Do the fourth thing.</li>
            </ol>
        </body>
        </html>
        """
        
        let draft = HeuristicParser.parse(html: html)
        
        XCTAssertNotNil(draft)
        
        // All step prefixes should be removed
        XCTAssertEqual(draft?.instructions[0], "Do the first thing carefully.")
        XCTAssertEqual(draft?.instructions[1], "Do the second thing.")
        XCTAssertEqual(draft?.instructions[2], "Do the third thing.")
        XCTAssertEqual(draft?.instructions[3], "Do the fourth thing.")
    }
    
    // MARK: - Test Fixtures
    
    private var standardFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Grandma's Apple Pie | Home Cooking</title>
            <meta property="og:title" content="Grandma's Apple Pie">
        </head>
        <body>
            <nav><a href="/">Home</a></nav>
            
            <h1>Grandma's Apple Pie</h1>
            
            <h2>Ingredients</h2>
            <ul>
                <li>2 1/2 cups all-purpose flour</li>
                <li>1 teaspoon salt</li>
                <li>1 cup cold butter, cubed</li>
                <li>6-8 tablespoons ice water</li>
                <li>6 large apples, peeled and sliced</li>
                <li>3/4 cup sugar</li>
                <li>2 tablespoons flour</li>
                <li>1 teaspoon cinnamon</li>
                <li>1/4 teaspoon nutmeg</li>
                <li>2 tablespoons butter</li>
            </ul>
            
            <h2>Instructions</h2>
            <ol>
                <li>Combine 2 1/2 cups flour and salt in a large bowl.</li>
                <li>Gradually add ice water, mixing until dough forms.</li>
                <li>Preheat oven to 425°F.</li>
                <li>Combine sliced apples, sugar, flour, and spices.</li>
                <li>Roll out dough and place in pie plate.</li>
                <li>Add apple filling and dot with butter.</li>
                <li>Roll out remaining dough and place over filling.</li>
                <li>Bake for 45-50 minutes until golden.</li>
                <li>Cool on wire rack before serving.</li>
            </ol>
            
            <footer><p>Copyright</p></footer>
        </body>
        </html>
        """
    }
    
    private var classBasedFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Quick Banana Bread</title>
            <meta property="og:image" content="https://example.com/banana-bread.jpg">
        </head>
        <body>
            <h1>Quick Banana Bread</h1>
            
            <div class="ingredients-section">
                <h3>What You'll Need</h3>
                <div class="ingredient">3 ripe bananas</div>
                <div class="ingredient">1/3 cup melted butter</div>
                <div class="ingredient">3/4 cup sugar</div>
                <div class="ingredient">1 egg, beaten</div>
                <div class="ingredient">1 teaspoon vanilla</div>
                <div class="ingredient">1 teaspoon baking soda</div>
                <div class="ingredient">Pinch of salt</div>
                <div class="ingredient">1 1/2 cups flour</div>
            </div>
            
            <div class="directions-section">
                <h3>Directions</h3>
                <p class="instruction">1. Preheat oven to 350°F and grease a loaf pan.</p>
                <p class="instruction">2. Mash the bananas in a bowl.</p>
                <p class="instruction">3. Stir in melted butter.</p>
                <p class="instruction">4. Mix in sugar, egg, and vanilla.</p>
                <p class="instruction">5. Add baking soda and salt.</p>
                <p class="instruction">6. Fold in flour until combined.</p>
                <p class="instruction">7. Pour into pan.</p>
                <p class="instruction">8. Bake for 55-60 minutes.</p>
                <p class="instruction">9. Cool before slicing.</p>
            </div>
        </body>
        </html>
        """
    }
    
    private var minimalFixture: String {
        """
        <!DOCTYPE html>
        <html>
        <head><title>Simple Scrambled Eggs</title></head>
        <body>
            <h1>Simple Scrambled Eggs</h1>
            
            <h2>Ingredients</h2>
            <p>
                3 large eggs<br>
                1 tablespoon butter<br>
                2 tablespoons milk<br>
                Salt and pepper
            </p>
            
            <h2>Method</h2>
            <p>Step 1: Whisk eggs with milk and seasonings.</p>
            <p>Step 2: Melt butter in a pan.</p>
            <p>Step 3: Pour in eggs and let sit briefly.</p>
            <p>Step 4: Gently fold eggs with a spatula.</p>
            <p>Step 5: Continue until just set.</p>
            <p>Step 6: Serve immediately.</p>
        </body>
        </html>
        """
    }
}
