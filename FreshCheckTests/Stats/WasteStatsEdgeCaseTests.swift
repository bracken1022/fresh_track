import XCTest
@testable import FreshCheck

final class WasteStatsEdgeCaseTests: XCTestCase {

    // MARK: - 100% wasted

    func test_wastePercentage_100_whenAllWasted() {
        let records = [
            makeRecord(outcome: .wasted),
            makeRecord(outcome: .wasted),
            makeRecord(outcome: .wasted),
        ]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 100.0, accuracy: 0.1,
            "Waste percentage should be 100% when all items are wasted")
    }

    // MARK: - 0% wasted (all consumed)

    func test_wastePercentage_0_whenAllConsumed() {
        let records = [
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .consumed),
        ]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 0.0, accuracy: 0.1,
            "Waste percentage should be 0% when all items are consumed")
    }

    // MARK: - Single record

    func test_wastePercentage_singleWastedRecord() {
        let records = [makeRecord(outcome: .wasted)]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 100.0, accuracy: 0.1)
    }

    func test_wastePercentage_singleConsumedRecord() {
        let records = [makeRecord(outcome: .consumed)]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 0.0, accuracy: 0.1)
    }

    // MARK: - Category counts edge cases

    func test_wastedCountByCategory_emptyForAllConsumed() {
        let records = [
            makeRecord(category: .produce, outcome: .consumed),
            makeRecord(category: .meat, outcome: .consumed),
        ]
        let counts = WasteStatsCalculator.wastedCountByCategory(from: records)
        XCTAssertTrue(counts.isEmpty,
            "wastedCountByCategory should return empty dict when all items consumed")
    }

    func test_wastedCountByCategory_emptyWhenNoRecords() {
        let counts = WasteStatsCalculator.wastedCountByCategory(from: [])
        XCTAssertTrue(counts.isEmpty)
    }

    func test_wastedCountByCategory_allFiveCategories() {
        let records = [
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .meat, outcome: .wasted),
            makeRecord(category: .dairy, outcome: .wasted),
            makeRecord(category: .packaged, outcome: .wasted),
            makeRecord(category: .other, outcome: .wasted),
        ]
        let counts = WasteStatsCalculator.wastedCountByCategory(from: records)
        XCTAssertEqual(counts.count, 5, "Should have entries for all 5 categories")
        for category in FoodCategory.allCases {
            XCTAssertEqual(counts[category], 1,
                "Each category should have exactly 1 wasted item")
        }
    }

    func test_wastedCountByCategory_excludesConsumedFromCounts() {
        let records = [
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .produce, outcome: .consumed),
            makeRecord(category: .produce, outcome: .consumed),
        ]
        let counts = WasteStatsCalculator.wastedCountByCategory(from: records)
        XCTAssertEqual(counts[.produce], 1,
            "Should only count wasted items, not consumed")
    }

    // MARK: - Helper

    private func makeRecord(category: FoodCategory = .produce, outcome: DisposalOutcome) -> WasteRecord {
        WasteRecord(
            foodItemName: "Test",
            category: category,
            addedDate: Date(),
            expiryDate: Date(),
            outcome: outcome
        )
    }
}
