import XCTest
@testable import FreshCheck

final class FoodItemEdgeCaseTests: XCTestCase {

    // MARK: - Boundary: exactly 3 days remaining should be .expiringSoon

    func test_status_expiringSoon_whenExactlyThreeDaysRemaining() {
        // Spec: 0-3 days = expiringSoon. Exactly 3 days should be expiringSoon, not fresh.
        let item = FoodItem(
            name: "Yogurt",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.status, .expiringSoon,
            "Item with exactly 3 days remaining should be .expiringSoon per spec (0-3 days)")
    }

    func test_status_fresh_whenFourDaysRemaining() {
        // 4 days is more than 3, so should be .fresh
        let item = FoodItem(
            name: "Lettuce",
            category: .produce,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 4, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.status, .fresh,
            "Item with 4 days remaining should be .fresh (more than 3 days)")
    }

    // MARK: - Negative daysRemaining (already expired)

    func test_daysRemaining_negativeWhenExpired() {
        let item = FoodItem(
            name: "Old Chicken",
            category: .meat,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            confidenceSource: .shelfLife
        )
        XCTAssertEqual(item.daysRemaining, -5,
            "daysRemaining should be negative for items past their expiry date")
        XCTAssertEqual(item.status, .expired)
    }

    func test_daysRemaining_zeroOnExpiryDay() {
        // Item expiring "today" — daysRemaining should be 0
        let item = FoodItem(
            name: "Milk",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 0, to: Date())!,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.daysRemaining, 0,
            "daysRemaining should be 0 on the expiry day")
        // 0 days remaining is within 0-3, should be expiringSoon (not expired)
        XCTAssertEqual(item.status, .expiringSoon,
            "Item expiring today (0 days remaining) should be .expiringSoon per spec")
    }

    func test_status_expiringSoon_whenExpiryDateIsTodayAtMidnight() {
        // Regression test: ensure startOfDay comparison works correctly
        // Item with expiryDate at midnight today should be expiringSoon, not expired
        let midnight = Calendar.current.startOfDay(for: Date())
        let item = FoodItem(
            name: "Midnight Milk",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: midnight,
            confidenceSource: .ocr
        )
        XCTAssertEqual(item.status, .expiringSoon,
            "Item expiring today at midnight should be .expiringSoon, not .expired")
    }

    // MARK: - Consumed/Wasted status overrides computed status

    func test_status_consumed_overridesExpiredComputation() {
        let item = FoodItem(
            name: "Eaten Yogurt",
            category: .dairy,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!,
            confidenceSource: .ocr
        )
        item.disposalStatus = .consumed
        XCTAssertEqual(item.status, .consumed,
            "Consumed status should override expired computation")
    }

    func test_status_wasted_overridesFreshComputation() {
        let item = FoodItem(
            name: "Wasted Broccoli",
            category: .produce,
            photoURL: "",
            addedDate: Date(),
            expiryDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
            confidenceSource: .shelfLife
        )
        item.disposalStatus = .wasted
        XCTAssertEqual(item.status, .wasted,
            "Wasted status should override fresh computation")
    }
}
