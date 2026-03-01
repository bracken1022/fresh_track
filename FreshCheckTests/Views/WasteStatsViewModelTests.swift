// FreshCheckTests/Views/WasteStatsViewModelTests.swift
import XCTest
@testable import FreshCheck

final class WasteStatsTests: XCTestCase {

    func test_wastePercentage_calculatesCorrectly() {
        let records = [
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .consumed),
            makeRecord(outcome: .wasted),
            makeRecord(outcome: .wasted),
        ]
        let percentage = WasteStatsCalculator.wastePercentage(from: records)
        XCTAssertEqual(percentage, 50.0, accuracy: 0.1)
    }

    func test_wastePercentage_zeroWhenEmpty() {
        let percentage = WasteStatsCalculator.wastePercentage(from: [])
        XCTAssertEqual(percentage, 0.0)
    }

    func test_countByCategory_groupsCorrectly() {
        let records = [
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .produce, outcome: .wasted),
            makeRecord(category: .meat, outcome: .wasted),
        ]
        let counts = WasteStatsCalculator.wastedCountByCategory(from: records)
        XCTAssertEqual(counts[.produce], 2)
        XCTAssertEqual(counts[.meat], 1)
    }

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
