// FreshCheck/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(L10n.tr("tab.fridge"), systemImage: AppTheme.Icons.fridgeTab) }
            WasteStatsView()
                .tabItem { Label(L10n.tr("tab.stats"), systemImage: AppTheme.Icons.statsTab) }
        }
        .tint(AppTheme.Colors.accent)
        .task {
            let granted = await NotificationService.requestPermission()
            if granted {
                let message = NotificationService.buildDigestMessage(for: items)
                NotificationService.scheduleUsingSavedTime(message: message)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
    }
}
