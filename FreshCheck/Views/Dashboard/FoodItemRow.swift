// FreshCheck/Views/Dashboard/FoodItemRow.swift
import SwiftUI

struct FoodItemRow: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            // Photo thumbnail
            Group {
                if let image = PhotoStorageService.load(from: item.photoURL) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(item.category.icon).font(.title2)
                }
            }
            .frame(width: AppTheme.Size.photoThumbnail, height: AppTheme.Size.photoThumbnail)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(item.name)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                categoryBadge
            }

            Spacer()

            VStack(alignment: .trailing, spacing: AppTheme.Spacing.xs) {
                daysLabel
                statusBadge
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    private var categoryBadge: some View {
        let display = item.displayCategory
        let color = AppTheme.Colors.forDisplayCategory(display)
        return Text("\(display.icon) \(display.title)")
            .font(AppTheme.Typography.captionBold)
            .foregroundColor(color)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private var daysLabel: some View {
        let days = item.daysRemaining
        let text = days < 0 ? L10n.tr("status.expired") : days == 0 ? L10n.tr("status.today") : "\(days)d"
        return Text(text)
            .font(AppTheme.Typography.captionBold)
            .foregroundColor(AppTheme.Colors.forStatus(item.status))
    }

    private var statusBadge: some View {
        let color = AppTheme.Colors.forStatus(item.status)
        let statusText: String = switch item.status {
            case .fresh: L10n.tr("status.fresh")
            case .expiringSoon: L10n.tr("status.expiringSoonShort")
            case .expired: L10n.tr("status.expired")
            default: ""
        }
        return Text(statusText)
            .font(AppTheme.Typography.captionBold)
            .foregroundColor(color)
            .padding(.horizontal, AppTheme.Spacing.sm)
            .padding(.vertical, AppTheme.Spacing.xs)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
