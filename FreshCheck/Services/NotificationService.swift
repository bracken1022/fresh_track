// FreshCheck/Services/NotificationService.swift
import Foundation
import UserNotifications

final class NotificationService {
    static let reminderHourKey = "daily_reminder_hour"
    static let reminderMinuteKey = "daily_reminder_minute"
    static let defaultReminderHour = 8
    static let defaultReminderMinute = 0

    private static let categoryID = "SINGLE_ITEM_EXPIRY"
    static let actionConsumed = "ACTION_CONSUMED"
    static let actionWasted  = "ACTION_WASTED"
    static let userInfoItemUUID = "itemUUID"

    // MARK: - Category registration (call once at launch)
    static func registerActionCategories() {
        let consumedAction = UNNotificationAction(
            identifier: actionConsumed,
            title: L10n.tr("notif.action.consumed"),
            options: .foreground
        )
        let wastedAction = UNNotificationAction(
            identifier: actionWasted,
            title: L10n.tr("notif.action.wasted"),
            options: [.foreground, .destructive]
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [consumedAction, wastedAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Permission
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Time helpers
    static func currentReminderTime() -> (hour: Int, minute: Int) {
        let defaults = UserDefaults.standard
        let hasHour   = defaults.object(forKey: reminderHourKey) != nil
        let hasMinute = defaults.object(forKey: reminderMinuteKey) != nil
        let hour   = hasHour   ? defaults.integer(forKey: reminderHourKey)   : defaultReminderHour
        let minute = hasMinute ? defaults.integer(forKey: reminderMinuteKey) : defaultReminderMinute
        return (hour, minute)
    }

    static func saveReminderTime(hour: Int, minute: Int) {
        UserDefaults.standard.set(hour,   forKey: reminderHourKey)
        UserDefaults.standard.set(minute, forKey: reminderMinuteKey)
    }

    // MARK: - Smart scheduling (primary API)
    static func scheduleSmartDigest(items: [FoodItem]) {
        let saved = currentReminderTime()
        let active = items.filter { $0.status != .consumed && $0.status != .wasted }
        let (message, singleItem) = buildSmartContent(for: active)
        scheduleDigestInternal(hour: saved.hour, minute: saved.minute,
                               message: message, singleItem: singleItem)
    }

    // MARK: - Legacy API (kept for backward compat with external callers; not used internally)
    static func scheduleUsingSavedTime(message: String?) {
        let saved = currentReminderTime()
        scheduleDailyDigest(hour: saved.hour, minute: saved.minute, message: message)
    }

    static func scheduleDailyDigest(hour: Int = defaultReminderHour,
                                    minute: Int = defaultReminderMinute,
                                    message: String?) {
        scheduleDigestInternal(hour: hour, minute: minute, message: message, singleItem: nil)
    }

    // MARK: - Content builder (internal for testability)
    static func buildSmartContent(for items: [FoodItem]) -> (message: String?, singleItem: FoodItem?) {
        // No active items in fridge — skip notification entirely (nothing to track)
        guard !items.isEmpty else { return (nil, nil) }

        let expired = items.filter { $0.daysRemaining < 0 }
        let urgent  = items.filter { $0.daysRemaining >= 0 && $0.daysRemaining <= 3 }

        if !expired.isEmpty {
            let count = expired.count
            let names = expired.prefix(3).map { $0.name }.joined(separator: ", ")
            let msg = count == 1
                ? "1 expired item to clear out: \(names)."
                : "\(count) expired items to clear out: \(names)."
            return (msg, nil)
        }

        if urgent.count == 1 {
            let item = urgent[0]
            let days = item.daysRemaining
            let msg = L10n.tr("notif.body.single")
                .replacingOccurrences(of: "{name}", with: item.name)
                .replacingOccurrences(of: "{days}", with: "\(days)")
            return (msg, item)
        }

        if urgent.count > 1 {
            let names = urgent.prefix(3).map { $0.name }.joined(separator: ", ")
            return ("\(urgent.count) items need attention: \(names).", nil)
        }

        return (L10n.tr("notif.body.allClear"), nil)
    }

    // MARK: - Private
    private static func scheduleDigestInternal(hour: Int, minute: Int,
                                               message: String?, singleItem: FoodItem?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-digest"])
        guard let message, !message.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = "Fridge Check"
        content.body  = message
        content.sound = .default

        if let item = singleItem {
            content.categoryIdentifier = categoryID
            content.userInfo = [userInfoItemUUID: item.id.uuidString]
        }

        var components = DateComponents()
        components.hour   = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-digest", content: content, trigger: trigger)
        center.add(request)
    }
}
