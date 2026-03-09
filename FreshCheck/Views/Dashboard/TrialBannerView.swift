// FreshCheck/Views/Dashboard/TrialBannerView.swift
import SwiftUI

struct TrialBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.orange)
                Text(L10n.tr("trial.banner"))
                    .font(AppTheme.Typography.captionBold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(AppTheme.Radius.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}
