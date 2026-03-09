// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData

@main
struct FreshCheckApp: App {
    @AppStorage(L10n.appLanguageStorageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue

    private let subscriptionService = SubscriptionService.shared

    init() {
        // Start trial clock on very first launch
        if UserDefaults.standard.object(forKey: SubscriptionService.trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: SubscriptionService.trialStartKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appLanguageRawValue)
                .environment(\.locale, L10n.localeForAppLanguage())
                .environment(subscriptionService)
                .task { await subscriptionService.load() }
        }
        .modelContainer(for: [FoodItem.self, WasteRecord.self])
    }
}
