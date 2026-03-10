// FreshCheck/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(L10n.tr("tab.fridge"), systemImage: AppTheme.Icons.fridgeTab) }
            WasteStatsView()
                .tabItem { Label(L10n.tr("tab.stats"), systemImage: AppTheme.Icons.statsTab) }
        }
        .tint(AppTheme.Colors.accent)
        // Re-schedule digest on every launch (covers returning users; new users also
        // schedule in OnboardingView.onDismiss, but scheduleSmartDigest is idempotent).
        .task {
            let granted = await NotificationService.requestPermission()
            if granted {
                NotificationService.scheduleSmartDigest(items: items)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { hasSeenOnboarding && !subscriptionService.isAccessAllowed },
            set: { _ in }
        )) {
            PaywallView(isDismissible: false)
        }
    }
}
