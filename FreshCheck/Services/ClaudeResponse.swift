// FreshCheck/Services/ClaudeResponse.swift
import Foundation

struct FoodAnalysis: Codable {
    let name: String
    let category: FoodCategory
    let expiryDate: String         // ISO 8601 string from Claude
    let confidenceSource: ConfidenceSource
    let shelfLifeDays: Int?

    var parsedExpiryDate: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: expiryDate)
    }
}
