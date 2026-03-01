import XCTest
@testable import FreshCheck

final class FoodItemTests: XCTestCase {

    func test_status_fresh_whenMoreThanThreeDaysRemaining() {
        let item = FoodItem(
            name: "Broccoli",
            category: .produce,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.status, .fresh)
    }

    func test_status_expiringSoon_whenThreeDaysOrLess() {
        let item = FoodItem(
            name: "Milk",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.status, .expiringSoon)
    }

    func test_status_expired_whenPastExpiryDate() {
        let item = FoodItem(
            name: "Chicken",
            category: .meat,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.status, .expired)
    }

    func test_daysRemaining_returnsCorrectCount() {
        let item = FoodItem(
            name: "Yogurt",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.daysRemaining, 4)
    }
}
