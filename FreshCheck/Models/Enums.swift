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

enum FoodDisplayCategory: String, CaseIterable, Identifiable {
    case meats
    case vegetables
    case fruits
    case others

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meats: return "Meats"
        case .vegetables: return "Vegetables"
        case .fruits: return "Fruits"
        case .others: return "Others"
        }
    }

    var icon: String {
        switch self {
        case .meats: return "🥩"
        case .vegetables: return "🥬"
        case .fruits: return "🍎"
        case .others: return "🍽️"
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
