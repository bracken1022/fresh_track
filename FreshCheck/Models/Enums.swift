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

    var localizedName: String {
        switch self {
        case .produce: return L10n.tr("foodCategory.produce")
        case .meat: return L10n.tr("foodCategory.meat")
        case .dairy: return L10n.tr("foodCategory.dairy")
        case .packaged: return L10n.tr("foodCategory.packaged")
        case .other: return L10n.tr("foodCategory.other")
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
        case .meats: return L10n.tr("category.meats")
        case .vegetables: return L10n.tr("category.vegetables")
        case .fruits: return L10n.tr("category.fruits")
        case .others: return L10n.tr("category.others")
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
