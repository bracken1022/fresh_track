// FreshCheck/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Fridge", systemImage: AppTheme.Icons.fridgeTab) }
            WasteStatsView()
                .tabItem { Label("Stats", systemImage: AppTheme.Icons.statsTab) }
        }
        .tint(AppTheme.Colors.accent)
        .task {
            let granted = await NotificationService.requestPermission()
            if granted {
                NotificationService.scheduleDailyDigest(items: items)
            }
        }
    }
}
