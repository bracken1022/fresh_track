# Smart Notifications Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the silent, manually-scheduled notification with a daily smart digest that fires every day, adapts its message to fridge state, and adds one-tap Consumed/Wasted action buttons when exactly one item is expiring soon.

**Architecture:** `NotificationService` gains smart content logic and registers a `UNNotificationCategory` with two actions. A new `NotificationHandler` delegate saves the tapped action to UserDefaults; `DashboardView` reads it on appear and calls the existing `dispose()` path. Scheduling is triggered at onboarding completion, after each dispose, and when the app enters the foreground.

**Tech Stack:** UserNotifications framework, UNNotificationAction/UNNotificationCategory, SwiftData @Query, UserDefaults for pending-action handoff.

---

### Context: Key files and patterns

- `FreshCheck/Services/NotificationService.swift` — existing static service; has `buildDigestMessage`, `scheduleDailyDigest`, `scheduleUsingSavedTime`
- `FreshCheck/Views/Dashboard/DashboardView.swift` — has `@Query private var items: [FoodItem]`, `activeItems` computed var, `dispose(_:outcome:)` method
- `FreshCheck/Views/Onboarding/OnboardingView.swift` — sets `hasSeenOnboarding = true` in `onDismiss` of AddFoodFlow sheet (line 35)
- `FreshCheck/FreshCheckApp.swift` — `@main` App struct, `init()` sets trial date
- `FreshCheck/Models/FoodItem.swift` — has `daysRemaining: Int`, `status: ItemStatus`, `id: UUID`
- `FreshCheck/Models/Enums.swift` — `DisposalOutcome: consumed | wasted`, `ItemStatus`
- `FreshCheck/Localization/L10n.swift` — `L10n.tr("key")` for localized strings
- Notification category ID to use: `"SINGLE_ITEM_EXPIRY"`
- Action identifiers: `"ACTION_CONSUMED"`, `"ACTION_WASTED"`
- UserDefaults keys for pending action: `"notif.pending.itemUUID"`, `"notif.pending.outcome"`

---

### Task 1: Add localization keys

**Files:**
- Modify: `FreshCheck/en.lproj/Localizable.strings`
- Modify: `FreshCheck/zh-Hans.lproj/Localizable.strings`

**Step 1: Add 4 new keys to English strings**

Append after the last `notif.*` key (after line 67):

```
"notif.action.consumed" = "Consumed";
"notif.action.wasted" = "Wasted";
"notif.body.allClear" = "Your fridge is looking good — nothing expiring soon.";
"notif.body.single" = "{name} expires in {days} day(s) — plan to use it?";
```

**Step 2: Add matching Chinese keys to zh-Hans**

Append after the last `notif.*` key (after line 68):

```
"notif.action.consumed" = "已食用";
"notif.action.wasted" = "已浪费";
"notif.body.allClear" = "冰箱一切正常，近期无食物过期。";
"notif.body.single" = "{name} 还有 {days} 天过期，记得使用！";
```

**Step 3: Build the app**

In Xcode: Product → Build (⌘B). Expected: build succeeds with no errors.

**Step 4: Commit**

```bash
git add FreshCheck/en.lproj/Localizable.strings FreshCheck/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add smart notification localization keys"
```

---

### Task 2: Extend NotificationService with smart content + action categories

**Files:**
- Modify: `FreshCheck/Services/NotificationService.swift`

**Step 1: Replace `buildDigestMessage` and add new methods**

Replace the entire file content with:

```swift
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

    // MARK: - Legacy API (used by NotificationSettingsView — keep for compat)
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
```

**Step 2: Build the app**

In Xcode: ⌘B. Expected: build succeeds.

**Step 3: Commit**

```bash
git add FreshCheck/Services/NotificationService.swift
git commit -m "feat: smart notification content + action category registration"
```

---

### Task 3: Create NotificationHandler (delegate + pending action)

**Files:**
- Create: `FreshCheck/Services/NotificationHandler.swift`

**Step 1: Create the file**

```swift
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
```

**Step 2: Build the app**

In Xcode: ⌘B. Expected: build succeeds.

**Step 3: Commit**

```bash
git add FreshCheck/Services/NotificationHandler.swift
git commit -m "feat: add NotificationHandler delegate for action tap handling"
```

---

### Task 4: Wire up FreshCheckApp

**Files:**
- Modify: `FreshCheck/FreshCheckApp.swift`

**Step 1: Read current file state, then replace with wired version**

Replace the full file content:

```swift
// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData
import UserNotifications

@main
struct FreshCheckApp: App {
    @AppStorage(L10n.appLanguageStorageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue

    private let subscriptionService = SubscriptionService.shared

    init() {
        // Start trial clock on very first launch
        if UserDefaults.standard.object(forKey: SubscriptionService.trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: SubscriptionService.trialStartKey)
        }

        // Register notification actions and set delegate
        NotificationService.registerActionCategories()
        UNUserNotificationCenter.current().delegate = NotificationHandler.shared
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
```

**Step 2: Build the app**

In Xcode: ⌘B. Expected: build succeeds.

**Step 3: Commit**

```bash
git add FreshCheck/FreshCheckApp.swift
git commit -m "feat: register notification delegate and action categories at launch"
```

---

### Task 5: Schedule notification at onboarding completion

**Files:**
- Modify: `FreshCheck/Views/Onboarding/OnboardingView.swift`

**Step 1: Read current file, then add @Query and schedule on dismiss**

Replace the full file content:

```swift
// FreshCheck/Views/Onboarding/OnboardingView.swift
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var showingAddFood = false
    @Query private var items: [FoodItem]

    private let pages: [(icon: String, headlineKey: String, subtitleKey: String, color: Color)] = [
        ("trash.slash.fill",   "onboarding.page1.headline", "onboarding.page1.subtitle", Color(red: 0.20, green: 0.60, blue: 0.35)),
        ("camera.fill",        "onboarding.page2.headline", "onboarding.page2.subtitle", Color(red: 0.20, green: 0.45, blue: 0.70)),
        ("bell.fill",          "onboarding.page3.headline", "onboarding.page3.subtitle", Color(red: 0.75, green: 0.40, blue: 0.10))
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(
                        icon: pages[index].icon,
                        headline: L10n.tr(pages[index].headlineKey),
                        subtitle: L10n.tr(pages[index].subtitleKey),
                        backgroundColor: pages[index].color
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            bottomControls
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showingAddFood, onDismiss: {
            hasSeenOnboarding = true
            Task {
                let granted = await NotificationService.requestPermission()
                if granted {
                    NotificationService.scheduleSmartDigest(items: items)
                }
            }
        }) {
            AddFoodFlow()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    Text(L10n.tr("onboarding.cta.next"))
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(pages[currentPage].color)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.lg)
                        .background(.white)
                        .cornerRadius(AppTheme.Radius.lg)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }
            } else {
                Button {
                    showingAddFood = true
                } label: {
                    Text(L10n.tr("onboarding.cta.getStarted"))
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(pages[currentPage].color)
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Spacing.lg)
                        .background(.white)
                        .cornerRadius(AppTheme.Radius.lg)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }
            }
        }
        .padding(.bottom, AppTheme.Spacing.xxl * 2)
    }
}
```

**Step 2: Build the app**

In Xcode: ⌘B. Expected: build succeeds.

**Step 3: Commit**

```bash
git add FreshCheck/Views/Onboarding/OnboardingView.swift
git commit -m "feat: request notification permission and schedule digest at onboarding completion"
```

---

### Task 6: Handle pending action + re-schedule on foreground in DashboardView

**Files:**
- Modify: `FreshCheck/Views/Dashboard/DashboardView.swift`

**Step 1: Add foreground re-schedule, pending action handling, and dispose re-schedule**

Make three additions to `DashboardView`:

**A. Add import and publisher property** after the existing `@State private var showingPaywall = false` line (around line 46), add:

```swift
    private let foregroundPublisher = NotificationCenter.default.publisher(
        for: UIApplication.willEnterForegroundNotification
    )
```

**B. Add `.onReceive` and `.onAppear` modifiers** to the NavigationStack's modifier chain (after the last `.sheet` before the closing brace of `body`):

Add after the existing `.overlay { ... }` modifier:

```swift
            .onAppear { handlePendingNotificationAction() }
            .onReceive(foregroundPublisher) { _ in
                NotificationService.scheduleSmartDigest(items: items)
                handlePendingNotificationAction()
            }
```

**C. Add `handlePendingNotificationAction()` private method** alongside the existing `dispose` method:

```swift
    private func handlePendingNotificationAction() {
        let defaults = UserDefaults.standard
        guard let uuidString = defaults.string(forKey: NotificationHandler.pendingItemUUIDKey),
              let outcome    = defaults.string(forKey: NotificationHandler.pendingOutcomeKey),
              let uuid       = UUID(uuidString: uuidString),
              let item       = items.first(where: { $0.id == uuid })
        else { return }

        defaults.removeObject(forKey: NotificationHandler.pendingItemUUIDKey)
        defaults.removeObject(forKey: NotificationHandler.pendingOutcomeKey)

        let disposalOutcome: DisposalOutcome = outcome == "consumed" ? .consumed : .wasted
        dispose(item, outcome: disposalOutcome)
    }
```

**D. Re-schedule in `dispose(_:outcome:)`** — add one line after `StreakService.recordActivity()`:

```swift
        NotificationService.scheduleSmartDigest(items: activeItems.filter { $0.id != item.id })
```

So the full `dispose` method becomes:

```swift
    private func dispose(_ item: FoodItem, outcome: DisposalOutcome) {
        let record = WasteRecord(
            foodItemName: item.name,
            category: item.category,
            addedDate: item.addedDate,
            expiryDate: item.expiryDate,
            outcome: outcome
        )
        context.insert(record)
        item.disposalStatus = outcome == .consumed ? .consumed : .wasted
        try? PhotoStorageService.delete(at: item.photoURL)
        StreakService.recordActivity()
        NotificationService.scheduleSmartDigest(items: activeItems.filter { $0.id != item.id })
    }
```

**Step 2: Build the app**

In Xcode: ⌘B. Expected: build succeeds with no errors.

**Step 3: Verify on simulator**

1. Run the app on simulator
2. Add a food item with expiry date = tomorrow
3. Background the app
4. In Xcode Simulator menu → Features → Trigger Notification (or wait for scheduled time)
5. Expected: notification appears with "Consumed" and "Wasted" action buttons (long-press on simulator)
6. Tap "Consumed" → app opens → item disappears from dashboard

**Step 4: Commit**

```bash
git add FreshCheck/Views/Dashboard/DashboardView.swift
git commit -m "feat: handle notification actions and re-schedule digest on foreground"
```

---

### Final: Build and push

**Step 1: Final build check**

In Xcode: Product → Clean Build Folder (⇧⌘K), then ⌘B. Expected: clean build, zero errors.

**Step 2: Push**

```bash
git push origin main
```
