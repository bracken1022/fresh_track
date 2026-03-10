// FreshCheck/Services/NotificationHandler.swift
import UserNotifications

/// UNUserNotificationCenterDelegate that handles notification action taps.
/// When the user taps Consumed or Wasted from the lock screen, this saves
/// the intent to UserDefaults. DashboardView picks it up on next appear.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    static let pendingItemUUIDKey = "notif.pending.itemUUID"
    static let pendingOutcomeKey  = "notif.pending.outcome"

    private override init() { super.init() }

    // Called when user taps a notification action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionID = response.actionIdentifier
        guard actionID == NotificationService.actionConsumed || actionID == NotificationService.actionWasted,
              let itemUUID = response.notification.request.content.userInfo[NotificationService.userInfoItemUUID] as? String
        else {
            completionHandler()
            return
        }

        let outcome = actionID == NotificationService.actionConsumed ? "consumed" : "wasted"
        UserDefaults.standard.set(itemUUID, forKey: Self.pendingItemUUIDKey)
        UserDefaults.standard.set(outcome,  forKey: Self.pendingOutcomeKey)
        completionHandler()
    }

    // Called when a notification arrives while app is in foreground — show as banner
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
