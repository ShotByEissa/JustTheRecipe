import XCTest
@testable import JustTheRecipe

final class ErrorHandlingTests: XCTestCase {
    
    // MARK: - AppError Tests
    
    func testAppErrorFromNetworkError() {
        XCTAssertEqual(AppError.from(.timeout), .networkTimeout)
        XCTAssertEqual(AppError.from(.noInternet), .noInternet)
        XCTAssertEqual(AppError.from(.serverError(500)), .serverError(500))
        XCTAssertEqual(AppError.from(.responseTooLarge), .contentTooLarge)
    }
    
    func testAppErrorFromExtractionError() {
        XCTAssertEqual(AppError.from(.noRecipeFound), .noRecipeFound)
    }
    
    func testAppErrorRetryable() {
        XCTAssertTrue(AppError.networkTimeout.isRetryable)
        XCTAssertTrue(AppError.serverError(503).isRetryable)
        XCTAssertFalse(AppError.noInternet.isRetryable)
        XCTAssertFalse(AppError.noRecipeFound.isRetryable)
        XCTAssertFalse(AppError.invalidURL(.malformed).isRetryable)
    }
    
    func testAppErrorShouldOfferManualEntry() {
        XCTAssertTrue(AppError.noRecipeFound.shouldOfferManualEntry)
        XCTAssertTrue(AppError.parsingFailed("reason").shouldOfferManualEntry)
        XCTAssertTrue(AppError.contentTooLarge.shouldOfferManualEntry)
        XCTAssertFalse(AppError.noInternet.shouldOfferManualEntry)
        XCTAssertFalse(AppError.networkTimeout.shouldOfferManualEntry)
    }
    
    func testURLValidationErrors() {
        XCTAssertEqual(URLValidationError.empty.message, "Please enter a URL.")
        XCTAssertTrue(URLValidationError.blockedDomain("facebook.com").message.contains("facebook.com"))
    }
    
    // MARK: - ContentValidator Tests
    
    func testValidDraft() {
        let draft = RecipeDraft(
            title: "Test Recipe",
            ingredients: ["flour", "sugar"],
            instructions: ["Mix ingredients together well."]
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.isEmpty)
    }
    
    func testEmptyTitle() {
        let draft = RecipeDraft(
            title: "",
            ingredients: ["flour"],
            instructions: ["Mix ingredients."]
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.contains { $0.contains("title") })
    }
    
    func testTitleTooLong() {
        let draft = RecipeDraft(
            title: String(repeating: "a", count: 600),
            ingredients: ["flour"],
            instructions: ["Mix ingredients."]
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.contains { $0.contains("Title") && $0.contains("long") })
    }
    
    func testEmptyIngredients() {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [],
            instructions: ["Step 1."]
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.contains { $0.contains("ingredient") })
    }
    
    func testEmptyInstructions() {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: ["flour"],
            instructions: []
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.contains { $0.contains("instruction") })
    }
    
    func testTooManyIngredients() {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: Array(repeating: "ingredient", count: 250),
            instructions: ["Step 1."]
        )
        
        let issues = ContentValidator.validate(draft)
        
        XCTAssertTrue(issues.contains { $0.contains("Too many ingredients") })
    }
    
    // MARK: - ContentValidator.sanitize Tests
    
    func testSanitizeTruncatesTitle() {
        let draft = RecipeDraft(
            title: String(repeating: "a", count: 600),
            ingredients: ["flour"],
            instructions: ["Mix ingredients."]
        )
        
        let sanitized = ContentValidator.sanitize(draft)
        
        XCTAssertEqual(sanitized.title.count, ContentValidator.maxTitleLength)
    }
    
    func testSanitizeTruncatesIngredients() {
        let longIngredient = String(repeating: "a", count: 1500)
        let draft = RecipeDraft(
            title: "Test",
            ingredients: [longIngredient],
            instructions: ["Mix ingredients."]
        )
        
        let sanitized = ContentValidator.sanitize(draft)
        
        XCTAssertEqual(sanitized.ingredients.first?.count, ContentValidator.maxIngredientLength)
    }
    
    func testSanitizeLimitsIngredientCount() {
        let draft = RecipeDraft(
            title: "Test",
            ingredients: Array(repeating: "ingredient", count: 300),
            instructions: ["Mix ingredients."]
        )
        
        let sanitized = ContentValidator.sanitize(draft)
        
        XCTAssertEqual(sanitized.ingredients.count, ContentValidator.maxIngredientCount)
    }
    
    // MARK: - Safe Array Access Tests
    
    func testSafeArrayAccess() {
        let array = ["a", "b", "c"]
        
        XCTAssertEqual(array[safe: 0], "a")
        XCTAssertEqual(array[safe: 2], "c")
        XCTAssertNil(array[safe: 3])
        XCTAssertNil(array[safe: -1])
    }
    
    func testSafeArrayAccessEmptyArray() {
        let array: [String] = []
        
        XCTAssertNil(array[safe: 0])
    }
    
    // MARK: - String Truncation Tests
    
    func testStringTruncation() {
        let long = "This is a long string that needs truncation"
        
        XCTAssertEqual(long.truncated(to: 10), "This is a ")
        XCTAssertEqual(long.truncated(to: 100), long)  // No change if under limit
    }
    
    func testStringSafeSubstring() {
        let str = "Hello World"
        
        XCTAssertEqual(str.safeSubstring(from: 0, length: 5), "Hello")
        XCTAssertEqual(str.safeSubstring(from: 6, length: 5), "World")
        XCTAssertEqual(str.safeSubstring(from: 100, length: 5), "")  // Beyond bounds
    }
}
