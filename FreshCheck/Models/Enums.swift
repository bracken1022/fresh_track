// FreshCheck/Models/Enums.swift
import Foundation

enum FoodCategory: String, Codable, CaseIterable {
    case produce, meat, dairy, packaged, other

    var icon: String {
        switch self {
        case .produce:  return "🥦"
        case .meat:     return "🥩"
        case .dairy:    return "🥛"
        case .packaged: return "📦"
        case .other:    return "🍽️"
        }
    }
}

enum ConfidenceSource: String, Codable {
    case ocr, shelfLife
}

enum ItemStatus: String, Codable {
    case fresh, expiringSoon, expired, consumed, wasted
}

enum DisposalOutcome: String, Codable {
    case consumed, wasted
}
