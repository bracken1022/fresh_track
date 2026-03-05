// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData

@main
struct FreshCheckApp: App {
    @AppStorage(L10n.appLanguageStorageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .id(appLanguageRawValue)
                .environment(\.locale, L10n.localeForAppLanguage())
        }
        .modelContainer(for: [FoodItem.self, WasteRecord.self])
    }
}
