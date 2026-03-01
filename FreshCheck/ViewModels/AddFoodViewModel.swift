// FreshCheck/ViewModels/AddFoodViewModel.swift
import Foundation
import SwiftUI

@Observable
final class AddFoodViewModel {
    var name: String = ""
    var category: FoodCategory = .other
    var expiryDate: Date = Date()
    var confidenceSource: ConfidenceSource = .shelfLife
    var isLoading: Bool = false
    var errorMessage: String?
    var analysisComplete: Bool = false

    var isExpiredOnAdd: Bool {
        expiryDate < Date()
    }

    func populate(from analysis: FoodAnalysis) {
        name = analysis.name
        category = analysis.category
        confidenceSource = analysis.confidenceSource
        expiryDate = analysis.parsedExpiryDate ?? Date()
        analysisComplete = true
    }
}
