import XCTest
@testable import FreshCheck

final class NotificationServiceEdgeCaseTests: XCTestCase {

    // MARK: - Message truncation at 5 items

    func test_buildDigestMessage_showsAllFiveItems_whenExactlyFiveExpiring() {
        let items = (1...5).map { i in
            makeFoodItem(name: "Item\(i)", daysUntilExpiry: i)
        }
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNotNil(message)
        // All 5 should appear in the message
        for i in 1...5 {
            XCTAssertTrue(message!.contains("Item\(i)"),
                "Message should contain Item\(i) when exactly 5 items are expiring")
        }
        XCTAssertTrue(message!.contains("5 items"),
            "Message should say '5 items'")
    }

    func test_buildDigestMessage_onlyShowsFirstFive_whenSixExpiring() {
        let items = (1...6).map { i in
            makeFoodItem(name: "Food\(i)", daysUntilExpiry: i <= 6 ? i : 10)
        }
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNotNil(message)
        // First 5 should appear
        for i in 1...5 {
            XCTAssertTrue(message!.contains("Food\(i)"),
                "Message should contain Food\(i) (one of first 5)")
        }
        // 6th should NOT appear in the names list
        XCTAssertFalse(message!.contains("Food6"),
            "Message should NOT list 6th item name (truncated to 5)")
        // But the count should still say 6
        XCTAssertTrue(message!.contains("6 items"),
            "Message should report total count of 6 items, even though only 5 names listed")
    }

    // MARK: - Single item message (singular form)

    func test_buildDigestMessage_singularForm_whenOneItemExpiring() {
        let items = [makeFoodItem(name: "Milk", daysUntilExpiry: 1)]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("1 item expiring"),
            "Message should use singular 'item' not 'items' for count of 1")
        XCTAssertFalse(message!.contains("1 items"),
            "Should not say '1 items'")
    }

    // MARK: - Expired items are included in digest

    func test_buildDigestMessage_includesExpiredItems() {
        let items = [
            makeFoodItem(name: "ExpiredChicken", daysUntilExpiry: -1),
            makeFoodItem(name: "FreshApple", daysUntilExpiry: 10),
        ]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("ExpiredChicken"),
            "Expired items should be included in the digest")
        XCTAssertFalse(message!.contains("FreshApple"),
            "Fresh items should NOT be included in the digest")
    }

    // MARK: - All items are fresh (no notification)

    func test_buildDigestMessage_returnsNil_whenAllItemsFresh() {
        let items = [
            makeFoodItem(name: "Apple", daysUntilExpiry: 7),
            makeFoodItem(name: "Carrots", daysUntilExpiry: 14),
        ]
        let message = NotificationService.buildDigestMessage(for: items)
        XCTAssertNil(message,
            "No digest message when all items are fresh")
    }

    // MARK: - Empty items list

    func test_buildDigestMessage_returnsNil_whenNoItems() {
        let message = NotificationService.buildDigestMessage(for: [])
        XCTAssertNil(message,
            "No digest message when there are no items")
    }

    // MARK: - Helper

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
