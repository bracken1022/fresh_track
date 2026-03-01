// FreshCheck/Services/NotificationService.swift
import Foundation
import UserNotifications

final class NotificationService {

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func scheduleDailyDigest(hour: Int = 8, minute: Int = 0, items: [FoodItem]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-digest"])

        guard let message = buildDigestMessage(for: items) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fridge Check"
        content.body = message
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily-digest",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    // Internal for testability
    static func buildDigestMessage(for items: [FoodItem]) -> String? {
        let expiringSoon = items.filter { $0.status == .expiringSoon || $0.status == .expired }
        guard !expiringSoon.isEmpty else { return nil }
        let names = expiringSoon.prefix(5).map { $0.name }.joined(separator: ", ")
        let count = expiringSoon.count
        return "\(count) item\(count == 1 ? "" : "s") expiring soon: \(names)."
    }
}
