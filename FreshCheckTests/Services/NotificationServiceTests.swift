// FreshCheckTests/Services/NotificationServiceTests.swift
import XCTest
@testable import FreshCheck

final class NotificationServiceTests: XCTestCase {

    func test_buildDigestMessage_listsSoonExpiringItems() {
        let items = [
            makeFoodItem(name: "Broccoli", daysUntilExpiry: 1),
            makeFoodItem(name: "Milk", daysUntilExpiry: 2),
            makeFoodItem(name: "Apple", daysUntilExpiry: 3),  // outside 2-day rule
        ]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertTrue(message!.contains("Broccoli"))
        XCTAssertTrue(message!.contains("Milk"))
        XCTAssertFalse(message!.contains("Apple"))
    }

    func test_buildDigestMessage_returnsNil_whenNothingExpiringSoon() {
        let items = [makeFoodItem(name: "Apple", daysUntilExpiry: 10)]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNil(message)
    }

    private func makeFoodItem(name: String, daysUntilExpiry: Int) -> FoodItem {
        FoodItem(
            name: name,
            category: .produce,
            photoURL: "",
            expiryDate: Calendar.current.date(byAdding: .day, value: daysUntilExpiry, to: Date())!,
            confidenceSource: .shelfLife
        )
    }
}
