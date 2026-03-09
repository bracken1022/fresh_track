// FreshCheck/Views/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var showingAddFood = false

    private let pages: [(icon: String, headlineKey: String, subtitleKey: String, color: Color)] = [
        ("trash.slash.fill",   "onboarding.page1.headline", "onboarding.page1.subtitle", Color(red: 0.20, green: 0.60, blue: 0.35)),
        ("camera.fill",        "onboarding.page2.headline", "onboarding.page2.subtitle", Color(red: 0.20, green: 0.45, blue: 0.70)),
        ("bell.fill",          "onboarding.page3.headline", "onboarding.page3.subtitle", Color(red: 0.75, green: 0.40, blue: 0.10))
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        icon: pages[index].icon,
                        headline: L10n.tr(pages[index].headlineKey),
                        subtitle: L10n.tr(pages[index].subtitleKey),
                        backgroundColor: pages[index].color
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomControls
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingAddFood, onDismiss: {
            hasSeenOnboarding = true
        }) {
            AddFoodFlow()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text(L10n.tr("onboarding.cta.next"))
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(pages[currentPage].color)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.lg)
                        .background(.white)
                        .cornerRadius(AppTheme.Radius.lg)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }
            } else {
                Button {
                    showingAddFood = true
                } label: {
                    Text(L10n.tr("onboarding.cta.getStarted"))
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(pages[currentPage].color)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.lg)
                        .background(.white)
                        .cornerRadius(AppTheme.Radius.lg)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }
            }
        }
        .padding(.bottom, AppTheme.Spacing.xxl * 2)
    }
}
