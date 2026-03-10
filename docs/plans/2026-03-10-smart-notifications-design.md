# Smart Notifications Design

## Goal
Transform the existing silent/manual notification system into a proactive daily fridge report with one-tap action buttons, so outcome-focused users act on expiring food without friction.

## User Persona
Outcome-focused: wants to reduce food waste, not build a daily ritual. Opens the app when they shop or cook. The habit trigger is a timely, specific nudge — not a generic reminder.

## Architecture

### Smart Message Logic
Daily digest fires every day once items exist. Message varies by fridge state:

| State | Message |
|---|---|
| No items | Skip notification |
| All fresh (>3 days) | "Your fridge is looking good — nothing expiring soon." |
| 1 item expiring ≤3 days | "{Name} expires in {X} days — plan to use it?" + actions |
| 2–5 items expiring | "{N} items need attention: Chicken, Milk…" |
| Any expired | "You have {N} expired item(s) to clear out." |

### Actionable Notifications
When exactly 1 item is expiring ≤3 days, add two action buttons:
- **Consumed** — marks item consumed, re-schedules digest
- **Wasted** — marks item wasted, re-schedules digest

The item's SwiftData URL is embedded in notification `userInfo`. The action identifier is passed alongside. On app open from action, `NotificationHandler` reads both, fetches the item, calls existing dispose logic.

For 2+ urgent items: no inline actions (can't determine which item user acted on). Tap opens dashboard.

### Scheduling Trigger Points
1. **Onboarding completes** — request permission + schedule first digest at default 8:00 AM
2. **Item added, consumed, or wasted** — re-schedule with fresh content
3. **App foregrounded** — re-schedule once per day (covers overnight expiry changes)

`NotificationSettingsView` (time picker) continues to work unchanged.

## Components

| Component | Change |
|---|---|
| `NotificationService` | Smart message logic, register UNNotificationCategory with actions |
| `NotificationHandler` | New class — UNUserNotificationCenterDelegate, handles action → dispose |
| `FreshCheckApp` | Set delegate on init, re-schedule on foreground |
| `AddFoodFlow` | Re-schedule after save |
| `DashboardView` / dispose path | Re-schedule after consume/waste |
| `OnboardingView` | Request permission + schedule on Get Started dismiss |
| `Localizable.strings` (EN + ZH) | ~4 new keys: action labels, all-clear message |

## Localization Keys (new)
- `notif.action.consumed` — "Consumed" / "已食用"
- `notif.action.wasted` — "Wasted" / "已浪费"
- `notif.body.allClear` — "Your fridge is looking good — nothing expiring soon." / "冰箱一切正常，近期无食物过期。"
- `notif.body.single` — "{name} expires in {days} day(s) — plan to use it?" / "{name} 还有 {days} 天过期，记得使用！"

## Out of Scope
- Background silent pushes (requires APNs server)
- Widget (separate sprint)
- Notification grouping / threading
