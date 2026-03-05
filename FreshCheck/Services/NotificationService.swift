// FreshCheck/Services/NotificationService.swift
import Foundation
import UserNotifications

final class NotificationService {
    static let reminderHourKey = "daily_reminder_hour"
    static let reminderMinuteKey = "daily_reminder_minute"
    static let defaultReminderHour = 8
    static let defaultReminderMinute = 0

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func currentReminderTime() -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        let hasHour = defaults.object(forKey: reminderHourKey) != nil
        let hasMinute = defaults.object(forKey: reminderMinuteKey) != nil
        let hour = hasHour ? defaults.integer(forKey: reminderHourKey) : defaultReminderHour
        let minute = hasMinute ? defaults.integer(forKey: reminderMinuteKey) : defaultReminderMinute
        return (hour, minute)
    }

    static func saveReminderTime(hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        defaults.set(hour, forKey: reminderHourKey)
        defaults.set(minute, forKey: reminderMinuteKey)
    }

    static func scheduleUsingSavedTime(items: [FoodItem]) {
        let saved = currentReminderTime()
        scheduleDailyDigest(hour: saved.hour, minute: saved.minute, items: items)
    }

    static func scheduleDailyDigest(hour: Int = defaultReminderHour, minute: Int = defaultReminderMinute, items: [FoodItem]) {
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
        let urgentItems = items.filter { $0.daysRemaining <= 2 }
        guard !urgentItems.isEmpty else { return nil }
        let names = urgentItems.prefix(5).map { $0.name }.joined(separator: ", ")
        let count = urgentItems.count
        return "\(count) item\(count == 1 ? "" : "s") expiring within 2 days or expired: \(names)."
    }
}
