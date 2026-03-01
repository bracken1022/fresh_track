import XCTest
@testable import FreshCheck

final class ClaudeVisionServiceEdgeCaseTests: XCTestCase {

    // MARK: - Malformed JSON response

    func test_parseResponse_throwsOnMalformedJSON() {
        let garbage = "not json at all".data(using: .utf8)!
        XCTAssertThrowsError(try ClaudeVisionService.parseResponse(garbage),
            "parseResponse should throw when given non-JSON data")
    }

    func test_parseResponse_throwsOnIncompleteJSON() {
        let json = """
        {
            "name": "Broccoli",
            "category": "produce"
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try ClaudeVisionService.parseResponse(data),
            "parseResponse should throw when required fields are missing")
    }

    func test_parseResponse_throwsOnInvalidCategory() {
        let json = """
        {
            "name": "Mystery Food",
            "category": "unknown_category",
            "expiryDate": "2026-03-10",
            "confidenceSource": "shelfLife",
            "shelfLifeDays": 5
        }
        """
        let data = json.data(using: .utf8)!
        XCTAssertThrowsError(try ClaudeVisionService.parseResponse(data),
            "parseResponse should throw when category is not a valid FoodCategory")
    }

    func test_parseResponse_throwsOnEmptyData() {
        let data = Data()
        XCTAssertThrowsError(try ClaudeVisionService.parseResponse(data),
            "parseResponse should throw on empty data")
    }

    // MARK: - capShelfLifeDays edge cases

    func test_capShelfLife_doesNotCapDairy() {
        // Design doc says cap is for "fresh produce" — dairy should NOT be capped
        let result = ClaudeVisionService.capShelfLifeDays(60, for: .dairy)
        XCTAssertEqual(result, 60,
            "Dairy should not be capped at 30 days")
    }

    func test_capShelfLife_doesNotCapOther() {
        let result = ClaudeVisionService.capShelfLifeDays(90, for: .other)
        XCTAssertEqual(result, 90,
            "Other category should not be capped")
    }

    func test_capShelfLife_capsMeatAt30Days() {
        // Implementation caps both .produce and .meat
        let result = ClaudeVisionService.capShelfLifeDays(45, for: .meat)
        XCTAssertEqual(result, 30,
            "Meat should be capped at 30 days")
    }

    func test_capShelfLife_doesNotChangeProduceUnder30() {
        let result = ClaudeVisionService.capShelfLifeDays(7, for: .produce)
        XCTAssertEqual(result, 7,
            "Produce under 30 days should not be changed")
    }

    func test_capShelfLife_exactlyAt30Days_noChange() {
        let result = ClaudeVisionService.capShelfLifeDays(30, for: .produce)
        XCTAssertEqual(result, 30,
            "Produce at exactly 30 days should not be changed")
    }

    func test_capShelfLife_packaged_allowsLargeValues() {
        let result = ClaudeVisionService.capShelfLifeDays(365, for: .packaged)
        XCTAssertEqual(result, 365,
            "Packaged goods should allow shelf life >30 days with no cap")
    }

    // MARK: - parseResponse with Claude API wrapper format

    func test_parseResponse_handlesClaudeAPIWrapper() throws {
        // Claude API wraps the response in a messages structure
        let wrappedJSON = """
        {
            "content": [{
                "type": "text",
                "text": "{\\"name\\": \\"Apple\\", \\"category\\": \\"produce\\", \\"expiryDate\\": \\"2026-03-08\\", \\"confidenceSource\\": \\"shelfLife\\", \\"shelfLifeDays\\": 7}"
            }]
        }
        """
        let data = wrappedJSON.data(using: .utf8)!
        let result = try ClaudeVisionService.parseResponse(data)
        XCTAssertEqual(result.name, "Apple")
        XCTAssertEqual(result.category, .produce)
        XCTAssertEqual(result.shelfLifeDays, 7)
    }
}
