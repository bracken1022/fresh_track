// FreshCheck/Models/FoodItem.swift
import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var category: FoodCategory
    var photoURL: String
    var addedDate: Date
    var expiryDate: Date
    var confidenceSource: ConfidenceSource
    var disposalStatus: ItemStatus

    init(
        name: String,
        category: FoodCategory,
        photoURL: String,
        addedDate: Date = Date(),
        expiryDate: Date,
        confidenceSource: ConfidenceSource
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.photoURL = photoURL
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.confidenceSource = confidenceSource
        self.disposalStatus = .fresh
    }

    var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let expiry = cal.startOfDay(for: expiryDate)
        return cal.dateComponents([.day], from: today, to: expiry).day ?? 0
    }

    var status: ItemStatus {
        if disposalStatus == .consumed || disposalStatus == .wasted {
            return disposalStatus
        }
        if daysRemaining < 0  { return .expired }
        if daysRemaining <= 3 { return .expiringSoon }
        return .fresh
    }

    var displayCategory: FoodDisplayCategory {
        if category == .meat { return .meats }
        if category == .produce {
            return Self.isLikelyFruit(name: name) ? .fruits : .vegetables
        }
        return .others
    }

    private static func isLikelyFruit(name: String) -> Bool {
        let normalized = name.lowercased()
        let keywords = [
            "apple", "banana", "orange", "grape", "mango", "pear", "peach", "plum",
            "berry", "berries", "strawberry", "blueberry", "raspberry", "blackberry",
            "kiwi", "melon", "watermelon", "pineapple", "papaya", "avocado", "cherry",
            "lemon", "lime", "mandarin", "tangerine", "coconut", "fig", "date"
        ]
        return keywords.contains(where: normalized.contains)
    }
}
