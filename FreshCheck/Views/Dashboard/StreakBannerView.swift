// FreshCheck/Views/Dashboard/StreakBannerView.swift
import SwiftUI

struct StreakBannerView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text(L10n.tr("streak.banner").replacingOccurrences(of: "{n}", with: "\(streak)"))
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(AppTheme.Colors.expiringSoon.opacity(0.12))
        .cornerRadius(AppTheme.Radius.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs)
    }
}
