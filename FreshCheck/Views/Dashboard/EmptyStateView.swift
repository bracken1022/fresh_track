// FreshCheck/Views/Dashboard/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    enum Variant {
        case neverLogged
        case allCleared
    }

    let variant: Variant
    let onLogFood: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image(systemName: variant == .neverLogged ? AppTheme.Icons.fridgeTab : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(variant == .neverLogged ? AppTheme.Colors.textSecondary : AppTheme.Colors.fresh)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(variant == .neverLogged
                     ? L10n.tr("empty.neverLogged.title")
                     : L10n.tr("empty.allCleared.title"))
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(variant == .neverLogged
                     ? L10n.tr("empty.neverLogged.desc")
                     : L10n.tr("empty.allCleared.desc"))
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
            }

            Button(action: onLogFood) {
                Label(L10n.tr("empty.cta"), systemImage: AppTheme.Icons.cameraTab)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.Radius.lg)
            }

            Spacer()
            Spacer()
        }
    }
}
