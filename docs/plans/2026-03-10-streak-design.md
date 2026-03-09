# Streak Counter & Improved Empty State Design

**Date:** 2026-03-10
**Status:** Approved
**Scope:** Week 3 — logging streak banner + context-aware empty state

---

## Problem

Users have no feedback loop for consistent logging behaviour. The empty state is generic and doesn't adapt to whether the user is brand new or has cleared their fridge.

## Goals

1. Reward daily logging habit with a visible streak counter (≥2 days)
2. Make the empty state motivational and context-aware

---

## Feature 1: Streak Counter

### What counts as activity
Any of:
- Logging a new food item (photo → save)
- Marking an item as consumed
- Marking an item as wasted

### Storage
Three `UserDefaults` keys (no SwiftData schema changes):

| Key | Type | Description |
|-----|------|-------------|
| `streak.lastActivityDate` | String (ISO date) | Last date an activity was recorded |
| `streak.currentStreak` | Int | Current consecutive day count |

### Logic (`StreakService.recordActivity()`)
```
today = Calendar.current date
lastDate = UserDefaults streak.lastActivityDate

if lastDate == today → already counted, do nothing
if lastDate == yesterday → streak += 1, lastDate = today
if lastDate < yesterday OR nil → streak = 1, lastDate = today
```

### Display
- `StreakBannerView` shown at top of `DashboardView` list
- Only visible when `currentStreak >= 2`
- Text: "{streak}-day streak — keep it up!"
- Style: orange accent, flame SF Symbol (`flame.fill`), subtle background

### Hook-in points
- `AddFoodFlow.saveItem()` → call `StreakService.recordActivity()` after `context.insert(item)`
- `DashboardView` consumed swipe action → call after status update
- `DashboardView` wasted swipe action → call after status update

---

## Feature 2: Context-Aware Empty State

### Two variants

| Variant | Condition | Headline | Subtext | Extra |
|---------|-----------|----------|---------|-------|
| `neverLogged` | Total FoodItem count (all statuses) == 0 | "Your fridge is empty" | "Tap the camera to log your first food item." | Camera button |
| `allCleared` | Active items == 0, but total > 0 | "All clear!" | "Nothing expiring. Log new food to stay on top." | Camera button |

Both variants show a tappable camera button in the empty state (opens `AddFoodFlow`), removing the need to find the toolbar button.

### Detection in DashboardView
```swift
@Query private var allItems: [FoodItem]  // no filter — all statuses
// activeItems already computed (disposalStatus == .fresh or .expiringSoon or .expired)

var emptyStateVariant: EmptyVariant? {
    guard filteredItems.isEmpty else { return nil }
    return allItems.isEmpty ? .neverLogged : .allCleared
}
```

---

## Architecture

### New Files
- `FreshCheck/Services/StreakService.swift` — static streak logic
- `FreshCheck/Views/Dashboard/StreakBannerView.swift` — streak UI component
- `FreshCheck/Views/Dashboard/EmptyStateView.swift` — context-aware empty state

### Modified Files
- `FreshCheck/Views/Camera/AddFoodFlow.swift` — call `StreakService.recordActivity()` on save
- `FreshCheck/Views/Dashboard/DashboardView.swift` — add streak banner, new empty state, streak calls on swipe actions
- `FreshCheck/en.lproj/Localizable.strings` — new keys
- `FreshCheck/zh-Hans.lproj/Localizable.strings` — new keys

---

## Localization Keys

```
"streak.banner" = "{n}-day streak — keep it up!";
"empty.neverLogged.title" = "Your fridge is empty";
"empty.neverLogged.desc" = "Tap below to log your first food item.";
"empty.allCleared.title" = "All clear!";
"empty.allCleared.desc" = "Nothing expiring. Log new food to stay on top.";
"empty.cta" = "Log Food";
```

---

## Out of Scope
- Streak history / calendar view
- Push notification for streak at risk
- Longest streak record
- Sharing streak to social media
