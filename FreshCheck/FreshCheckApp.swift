// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData

@main
struct FreshCheckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [FoodItem.self, WasteRecord.self])
    }
}
