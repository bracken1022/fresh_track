# Streak Counter & Empty State Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a logging streak banner (shown when streak ≥ 2 days) and a context-aware empty state with two variants: first-ever open vs. all-cleared.

**Architecture:** `StreakService` is a static enum writing to 3 `UserDefaults` keys. `StreakBannerView` reads via `@AppStorage` and renders only when streak ≥ 2. `EmptyStateView` takes a variant enum and renders the right copy + camera CTA. `DashboardView` wires both in, and `AddFoodFlow.saveItem()` calls `StreakService.recordActivity()`.

**Tech Stack:** SwiftUI, `@AppStorage` / `UserDefaults`, existing `AppTheme`, `L10n`, `AddFoodFlow`.

---

## Task 1: Add Localization Keys

**Files:**
- Modify: `FreshCheck/en.lproj/Localizable.strings`
- Modify: `FreshCheck/zh-Hans.lproj/Localizable.strings`

**Step 1: Append to `FreshCheck/en.lproj/Localizable.strings`**

```
"streak.banner" = " {n}-day streak — keep it up!";
"empty.neverLogged.title" = "Your fridge is empty";
"empty.neverLogged.desc" = "Tap below to log your first food item.";
"empty.allCleared.title" = "All clear!";
"empty.allCleared.desc" = "Nothing expiring. Log new food to stay on top.";
"empty.cta" = "Log Food";
```

Note: The streak banner key uses `{n}` as a placeholder — replaced in Swift with `String(currentStreak)` via simple string replacement, not `NSLocalizedString` format args.

**Step 2: Append to `FreshCheck/zh-Hans.lproj/Localizable.strings`**

```
"streak.banner" = " 已连续记录 {n} 天，继续保持！";
"empty.neverLogged.title" = "冰箱是空的";
"empty.neverLogged.desc" = "点击下方按钮，记录你的第一件食物。";
"empty.allCleared.title" = "全部清空！";
"empty.allCleared.desc" = "没有即将过期的食物。记录新食物，随时掌握新鲜度。";
"empty.cta" = "记录食物";
```

**Step 3: Commit**

```bash
git add FreshCheck/en.lproj/Localizable.strings FreshCheck/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add streak and empty state localization keys (EN + ZH)"
```

---

## Task 2: Create StreakService

**Files:**
- Create: `FreshCheck/Services/StreakService.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Services/StreakService.swift
import Foundation

enum StreakService {
    private static let lastActivityKey = "streak.lastActivityDate"
    private static let currentStreakKey = "streak.currentStreak"

    static var currentStreak: Int {
        UserDefaults.standard.integer(forKey: currentStreakKey)
    }

    static func recordActivity() {
        let today = Calendar.current.startOfDay(for: Date())
        let defaults = UserDefaults.standard

        if let stored = defaults.object(forKey: lastActivityKey) as? Date {
            let lastDay = Calendar.current.startOfDay(for: stored)

            if lastDay == today {
                // Already counted today — nothing to do
                return
            }

            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            if lastDay == yesterday {
                // Consecutive day — extend streak
                defaults.set(defaults.integer(forKey: currentStreakKey) + 1, forKey: currentStreakKey)
            } else {
                // Streak broken — reset to 1
                defaults.set(1, forKey: currentStreakKey)
            }
        } else {
            // First ever activity
            defaults.set(1, forKey: currentStreakKey)
        }

        defaults.set(today, forKey: lastActivityKey)
    }

    /// For testing and debug reset only
    static func reset() {
        UserDefaults.standard.removeObject(forKey: lastActivityKey)
        UserDefaults.standard.removeObject(forKey: currentStreakKey)
    }
}
```

**Step 2: Verify logic mentally**
- First call → streak = 1, lastActivityDate = today
- Same day call → no change
- Next day call → streak = 2
- Skip a day, call → streak = 1 (reset)

**Step 3: Commit**

```bash
git add FreshCheck/Services/StreakService.swift
git commit -m "feat: add StreakService with UserDefaults persistence"
```

---

## Task 3: Create StreakBannerView

**Files:**
- Create: `FreshCheck/Views/Dashboard/StreakBannerView.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Views/Dashboard/StreakBannerView.swift
import SwiftUI

struct StreakBannerView: View {
    let streak: Int

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "flame.fill")
                .foregroundColor(.orange)
            Text(L10n.tr("streak.banner").replacingOccurrences(of: "{n}", with: "\(streak)"))
                .font(AppTheme.Typography.captionBold)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.vertical, AppTheme.Spacing.sm)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(AppTheme.Radius.md)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.xs)
    }
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Views/Dashboard/StreakBannerView.swift
git commit -m "feat: add StreakBannerView component"
```

---

## Task 4: Create EmptyStateView

**Files:**
- Create: `FreshCheck/Views/Dashboard/EmptyStateView.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Views/Dashboard/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    enum Variant {
        case neverLogged
        case allCleared
    }

    let variant: Variant
    let onLogFood: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.xl) {
            Spacer()

            Image(systemName: variant == .neverLogged ? AppTheme.Icons.fridgeTab : "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(variant == .neverLogged ? AppTheme.Colors.textSecondary : AppTheme.Colors.fresh)

            VStack(spacing: AppTheme.Spacing.sm) {
                Text(variant == .neverLogged
                     ? L10n.tr("empty.neverLogged.title")
                     : L10n.tr("empty.allCleared.title"))
                    .font(AppTheme.Typography.title)
                    .foregroundColor(AppTheme.Colors.textPrimary)

                Text(variant == .neverLogged
                     ? L10n.tr("empty.neverLogged.desc")
                     : L10n.tr("empty.allCleared.desc"))
                    .font(AppTheme.Typography.body)
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
            }

            Button(action: onLogFood) {
                Label(L10n.tr("empty.cta"), systemImage: AppTheme.Icons.cameraTab)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppTheme.Spacing.xxl)
                    .padding(.vertical, AppTheme.Spacing.md)
                    .background(AppTheme.Colors.accent)
                    .cornerRadius(AppTheme.Radius.lg)
            }

            Spacer()
            Spacer()
        }
    }
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Views/Dashboard/EmptyStateView.swift
git commit -m "feat: add context-aware EmptyStateView with neverLogged and allCleared variants"
```

---

## Task 5: Wire Everything into DashboardView

**Files:**
- Modify: `FreshCheck/Views/Dashboard/DashboardView.swift`

**Step 1: Add allItems query and streak AppStorage**

Add these two properties right after the existing `@Query` on line 36:

```swift
@Query private var allItems: [FoodItem]   // all statuses — for empty state detection
@AppStorage(StreakService.currentStreakKey) private var currentStreak: Int = 0
```

Wait — `StreakService.currentStreakKey` is `private`. Change it to `internal` (remove `private`) in `StreakService.swift`:

```swift
static let currentStreakKey = "streak.currentStreak"   // remove `private`
```

**Step 2: Replace the `.overlay` block**

Find this in `DashboardView` (around line 136):

```swift
.overlay {
    if filteredItems.isEmpty {
        ContentUnavailableView(
            L10n.tr("dashboard.empty.title"),
            systemImage: AppTheme.Icons.fridgeTab,
            description: Text(L10n.tr("dashboard.empty.desc"))
        )
    }
}
```

Replace with:

```swift
.overlay {
    if filteredItems.isEmpty {
        let variant: EmptyStateView.Variant = allItems.isEmpty ? .neverLogged : .allCleared
        EmptyStateView(variant: variant) {
            showingAddFood = true
        }
    }
}
```

**Step 3: Add streak banner above the List**

Find this in `DashboardView.body` (around line 72):

```swift
VStack(spacing: AppTheme.Spacing.sm) {
    categoryFilters

    List {
```

Replace with:

```swift
VStack(spacing: AppTheme.Spacing.sm) {
    if currentStreak >= 2 {
        StreakBannerView(streak: currentStreak)
    }

    categoryFilters

    List {
```

**Step 4: Call StreakService in dispose()**

Find `dispose(_:outcome:)` at the bottom of `DashboardView`. Add `StreakService.recordActivity()` after `item.disposalStatus = ...`:

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
}
```

**Step 5: Commit**

```bash
git add FreshCheck/Views/Dashboard/DashboardView.swift FreshCheck/Services/StreakService.swift
git commit -m "feat: wire streak banner and context-aware empty state into DashboardView"
```

---

## Task 6: Call StreakService in AddFoodFlow

**Files:**
- Modify: `FreshCheck/Views/Camera/AddFoodFlow.swift`

**Step 1: Add `StreakService.recordActivity()` in `saveItem()`**

Find `saveItem()` at the bottom of `AddFoodFlow.swift`:

```swift
private func saveItem() {
    let item = FoodItem(
        name: vm.name,
        category: vm.category,
        photoURL: capturedPhotoPath,
        expiryDate: vm.expiryDate,
        confidenceSource: vm.confidenceSource
    )
    context.insert(item)
    dismiss()
}
```

Replace with:

```swift
private func saveItem() {
    let item = FoodItem(
        name: vm.name,
        category: vm.category,
        photoURL: capturedPhotoPath,
        expiryDate: vm.expiryDate,
        confidenceSource: vm.confidenceSource
    )
    context.insert(item)
    StreakService.recordActivity()
    dismiss()
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Views/Camera/AddFoodFlow.swift
git commit -m "feat: record streak activity when food item is saved"
```

---

## Done Checklist

- [ ] 6 EN + 6 ZH localization keys added
- [ ] `StreakService.recordActivity()` increments streak on new day, no-ops same day, resets on gap
- [ ] Streak banner hidden when streak < 2, visible when ≥ 2
- [ ] Banner shows correct count (e.g. "3-day streak — keep it up!")
- [ ] Empty state shows `neverLogged` variant when no items ever logged
- [ ] Empty state shows `allCleared` variant when items exist but fridge is currently empty
- [ ] "Log Food" button in empty state opens camera
- [ ] Logging food via camera triggers `StreakService.recordActivity()`
- [ ] Marking consumed/wasted triggers `StreakService.recordActivity()`
- [ ] Chinese language shows translated strings
- [ ] Build succeeds with no errors
