import XCTest
@testable import FreshCheck

final class ClaudeVisionServiceTests: XCTestCase {

    func test_parseResponse_validJSON_returnsFoodAnalysis() throws {
        let json = """
        {
            "name": "Broccoli",
            "category": "produce",
            "expiryDate": "2026-03-05",
            "confidenceSource": "shelfLife",
            "shelfLifeDays": 5
        }
        """
        let data = json.data(using: .utf8)!
        let result = try ClaudeVisionService.parseResponse(data)
        XCTAssertEqual(result.name, "Broccoli")
        XCTAssertEqual(result.category, .produce)
        XCTAssertEqual(result.confidenceSource, .shelfLife)
        XCTAssertEqual(result.shelfLifeDays, 5)
    }

    func test_parseResponse_ocrSource_hasNilShelfLifeDays() throws {
        let json = """
        {
            "name": "Whole Milk",
            "category": "dairy",
            "expiryDate": "2026-03-10",
            "confidenceSource": "ocr",
            "shelfLifeDays": null
        }
        """
        let data = json.data(using: .utf8)!
        let result = try ClaudeVisionService.parseResponse(data)
        XCTAssertEqual(result.confidenceSource, .ocr)
        XCTAssertNil(result.shelfLifeDays)
    }

    func test_resizeImage_reducesLargeImageToMaxDimension() {
        let largeImage = UIImage(systemName: "photo")!
        let resized = ClaudeVisionService.resizeImage(largeImage, maxDimension: 1024)
        let maxSide = max(resized.size.width, resized.size.height)
        XCTAssertLessThanOrEqual(maxSide, 1024)
    }

    func test_capShelfLife_clampsFreshProduceOver30Days() {
        let result = ClaudeVisionService.capShelfLifeDays(999, for: .produce)
        XCTAssertEqual(result, 30)
    }

    func test_capShelfLife_doesNotCapPackagedGoods() {
        let result = ClaudeVisionService.capShelfLifeDays(90, for: .packaged)
        XCTAssertEqual(result, 90)
    }
}
