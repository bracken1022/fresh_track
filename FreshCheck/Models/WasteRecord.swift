// FreshCheck/Models/WasteRecord.swift
import Foundation
import SwiftData

@Model
final class WasteRecord {
    var id: UUID
    var foodItemName: String
    var category: FoodCategory
    var addedDate: Date
    var expiryDate: Date
    var disposedDate: Date
    var outcome: DisposalOutcome

    init(
        foodItemName: String,
        category: FoodCategory,
        addedDate: Date,
        expiryDate: Date,
        disposedDate: Date = Date(),
        outcome: DisposalOutcome
    ) {
        self.id = UUID()
        self.foodItemName = foodItemName
        self.category = category
        self.addedDate = addedDate
        self.expiryDate = expiryDate
        self.disposedDate = disposedDate
        self.outcome = outcome
    }
}
