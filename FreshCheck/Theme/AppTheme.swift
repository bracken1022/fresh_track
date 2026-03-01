// FreshCheck/Theme/AppTheme.swift
import SwiftUI
import UIKit

enum AppTheme {

    // MARK: - Status Colors

    enum Colors {
        // Freshness status
        static let fresh = Color.green
        static let expiringSoon = Color.orange
        static let expired = Color.red

        // Surfaces
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let surfaceElevated = Color(uiColor: .tertiarySystemGroupedBackground)

        // Text hierarchy
        static let textPrimary = Color(uiColor: .label)
        static let textSecondary = Color(uiColor: .secondaryLabel)
        static let textTertiary = Color(uiColor: .tertiaryLabel)

        // Actions
        static let accent = Color.green
        static let consumed = Color.blue
        static let wasted = Color(uiColor: .systemGray)
        static let destructive = Color.red
        static let cameraButton = Color.white
        static let categoryMeats = Color.red
        static let categoryVegetables = Color.green
        static let categoryFruits = Color.orange
        static let categoryOthers = Color(uiColor: .systemGray)

        /// Returns the color for a given `ItemStatus`.
        static func forStatus(_ status: ItemStatus) -> Color {
            switch status {
            case .fresh:        return fresh
            case .expiringSoon: return expiringSoon
            case .expired:      return expired
            case .consumed:     return consumed
            case .wasted:       return wasted
            }
        }

        static func forDisplayCategory(_ category: FoodDisplayCategory) -> Color {
            switch category {
            case .meats: return categoryMeats
            case .vegetables: return categoryVegetables
            case .fruits: return categoryFruits
            case .others: return categoryOthers
            }
        }
    }

    // MARK: - Typography

    enum Typography {
        static let largeTitle = Font.largeTitle.bold()
        static let title      = Font.title2.bold()
        static let headline   = Font.headline
        static let subheadline = Font.subheadline
        static let body       = Font.body
        static let caption    = Font.caption
        static let captionBold = Font.caption.weight(.semibold)
    }

    // MARK: - Spacing (4pt grid)

    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Corner Radii

    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 10
        static let lg: CGFloat = 16
    }

    // MARK: - Component Sizes

    enum Size {
        static let photoThumbnail: CGFloat = 48
        static let photoLarge: CGFloat = 200
        static let shutterOuter: CGFloat = 72
        static let shutterInner: CGFloat = 62
        static let shutterStroke: CGFloat = 3
    }

    // MARK: - SF Symbols

    enum Icons {
        // Tabs
        static let fridgeTab = "refrigerator.fill"
        static let cameraTab = "camera.fill"
        static let statsTab  = "chart.bar.fill"

        // Status
        static let freshStatus    = "checkmark.circle.fill"
        static let expiringStatus = "exclamationmark.triangle.fill"
        static let expiredStatus  = "xmark.circle.fill"

        // Actions
        static let consumedAction = "checkmark.circle"
        static let wastedAction   = "trash"

        // Metadata
        static let calendar  = "calendar"
        static let aiSource  = "sparkles"
        static let ocrSource = "text.viewfinder"
        static let edit      = "pencil"

        /// Returns the icon name for a given `ItemStatus`.
        static func forStatus(_ status: ItemStatus) -> String {
            switch status {
            case .fresh:        return freshStatus
            case .expiringSoon: return expiringStatus
            case .expired:      return expiredStatus
            case .consumed:     return consumedAction
            case .wasted:       return wastedAction
            }
        }
    }
}
