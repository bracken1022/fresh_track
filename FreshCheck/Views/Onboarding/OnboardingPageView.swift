// FreshCheck/Views/Onboarding/OnboardingPageView.swift
import SwiftUI

struct OnboardingPageView: View {
    let icon: String          // SF Symbol name
    let headline: String
    let subtitle: String
    let backgroundColor: Color

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                VStack(spacing: AppTheme.Spacing.lg) {
                    Text(headline)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
