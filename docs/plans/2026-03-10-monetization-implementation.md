# Monetization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a StoreKit 2 subscription with a 7-day free trial, a day-6 warning banner, and a hard paywall gate when the trial expires without a subscription.

**Architecture:** `SubscriptionService` is an `@Observable` singleton that loads StoreKit 2 products, tracks entitlement via `Transaction.currentEntitlements`, and computes trial state from a `UserDefaults` date stamp set on first launch. `ContentView` shows a non-dismissible `PaywallView` fullScreenCover when access is not allowed. `DashboardView` shows a `TrialBannerView` when one day remains.

**Tech Stack:** StoreKit 2 (iOS 15+), SwiftUI `@Observable`, `UserDefaults`, existing `AppTheme` / `L10n`.

---

## Task 1: Add Localization Keys

**Files:**
- Modify: `FreshCheck/en.lproj/Localizable.strings`
- Modify: `FreshCheck/zh-Hans.lproj/Localizable.strings`

**Step 1: Append to `FreshCheck/en.lproj/Localizable.strings`**

```
"paywall.headline" = "Keep your fridge fresh";
"paywall.feature1" = "AI reads expiry dates from photos";
"paywall.feature2" = "Daily reminders before food expires";
"paywall.feature3" = "Track your food waste over time";
"paywall.cta.trial" = "Start 7-Day Free Trial";
"paywall.cta.subscribe" = "Subscribe Now";
"paywall.restore" = "Restore Purchases";
"paywall.save.badge" = "Save {pct}%";
"paywall.error.title" = "Purchase Failed";
"paywall.error.restore" = "Nothing to Restore";
"trial.banner" = "Your free trial ends tomorrow — subscribe to keep access.";
```

**Step 2: Append to `FreshCheck/zh-Hans.lproj/Localizable.strings`**

```
"paywall.headline" = "保持冰箱新鲜";
"paywall.feature1" = "AI 从照片读取保质期";
"paywall.feature2" = "食物过期前每日提醒";
"paywall.feature3" = "追踪你的食物浪费情况";
"paywall.cta.trial" = "开始 7 天免费试用";
"paywall.cta.subscribe" = "立即订阅";
"paywall.restore" = "恢复购买";
"paywall.save.badge" = "节省 {pct}%";
"paywall.error.title" = "购买失败";
"paywall.error.restore" = "暂无可恢复的购买";
"trial.banner" = "您的免费试用明天结束 — 订阅以继续使用。";
```

**Step 3: Commit**

```bash
git add FreshCheck/en.lproj/Localizable.strings FreshCheck/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add paywall and trial localization keys (EN + ZH)"
```

---

## Task 2: Create SubscriptionService

**Files:**
- Create: `FreshCheck/Services/SubscriptionService.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Services/SubscriptionService.swift
import StoreKit
import Observation

@Observable final class SubscriptionService {

    // MARK: - Constants
    static let shared = SubscriptionService()
    static let productIDs = ["foodai.pro.monthly", "foodai.pro.yearly"]
    static let trialStartKey = "trialStartDate"
    static let trialDurationDays = 7

    // MARK: - Published state
    var isSubscribed: Bool = false
    var products: [Product] = []
    var purchaseError: String? = nil
    var isLoading: Bool = false

    // MARK: - Computed
    var trialDaysRemaining: Int {
        guard let start = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date else {
            return Self.trialDurationDays
        }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, Self.trialDurationDays - days)
    }

    var isAccessAllowed: Bool {
        isSubscribed || trialDaysRemaining > 0
    }

    // MARK: - Init
    private init() {}

    // MARK: - Load
    func load() async {
        await fetchProducts()
        await refreshEntitlement()
        listenForTransactions()
    }

    private func fetchProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("SubscriptionService: failed to fetch products — \(error)")
        }
    }

    func refreshEntitlement() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.revocationDate == nil {
                hasActive = true
            }
        }
        isSubscribed = hasActive
    }

    private func listenForTransactions() {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlement()
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Savings badge
    /// Returns integer % saved annually vs monthly, or nil if products aren't loaded yet.
    func annualSavingsPct() -> Int? {
        guard let monthly = products.first(where: { $0.id == "foodai.pro.monthly" }),
              let annual  = products.first(where: { $0.id == "foodai.pro.yearly" }) else {
            return nil
        }
        let monthlyYear = monthly.price * 12
        guard monthlyYear > 0 else { return nil }
        let saving = (monthlyYear - annual.price) / monthlyYear
        return Int((saving * 100).rounded())
    }
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Services/SubscriptionService.swift
git commit -m "feat: add SubscriptionService with StoreKit 2 trial and entitlement logic"
```

---

## Task 3: Set Trial Start Date in FreshCheckApp + Inject Service

**Files:**
- Modify: `FreshCheck/FreshCheckApp.swift`

**Step 1: Replace current FreshCheckApp.swift**

```swift
// FreshCheck/FreshCheckApp.swift
import SwiftUI
import SwiftData

@main
struct FreshCheckApp: App {
    @AppStorage(L10n.appLanguageStorageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue

    private let subscriptionService = SubscriptionService.shared

    init() {
        // Start trial clock on very first launch
        if UserDefaults.standard.object(forKey: SubscriptionService.trialStartKey) == nil {
            UserDefaults.standard.set(Date(), forKey: SubscriptionService.trialStartKey)
        }
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

**Step 2: Commit**

```bash
git add FreshCheck/FreshCheckApp.swift
git commit -m "feat: set trial start date on first launch, inject SubscriptionService"
```

---

## Task 4: Create PaywallView

**Files:**
- Create: `FreshCheck/Views/Paywall/PaywallView.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Views/Paywall/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var service
    @Environment(\.dismiss) private var dismiss

    let isDismissible: Bool

    @State private var selectedProductID: String = "foodai.pro.yearly"

    private var selectedProduct: Product? {
        service.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    header
                    features
                    productPicker
                    ctaButton
                    restoreButton
                }
                .padding(AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.xxl)
            }

            if isDismissible {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .alert(L10n.tr("paywall.error.title"), isPresented: Binding(
            get: { service.purchaseError != nil },
            set: { if !$0 { service.purchaseError = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) { service.purchaseError = nil }
        } message: {
            Text(service.purchaseError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: AppTheme.Icons.fridgeTab)
                .font(.system(size: 56))
                .foregroundColor(AppTheme.Colors.accent)
            Text(L10n.tr("paywall.headline"))
                .font(AppTheme.Typography.largeTitle)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            featureRow(icon: "camera.viewfinder", key: "paywall.feature1")
            featureRow(icon: "bell.fill",         key: "paywall.feature2")
            featureRow(icon: "chart.bar.fill",    key: "paywall.feature3")
        }
    }

    private func featureRow(icon: String, key: String) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 24)
            Text(L10n.tr(key))
                .font(AppTheme.Typography.body)
        }
    }

    private var productPicker: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(service.products, id: \.id) { product in
                productCard(product)
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isAnnual = product.id == "foodai.pro.yearly"
        let savingsPct = service.annualSavingsPct()

        return Button { selectedProductID = product.id } label: {
            VStack(spacing: AppTheme.Spacing.sm) {
                if isAnnual, let pct = savingsPct, pct > 0 {
                    Text(L10n.tr("paywall.save.badge").replacingOccurrences(of: "{pct}", with: "\(pct)"))
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.accent)
                        .cornerRadius(AppTheme.Radius.sm)
                } else {
                    Spacer().frame(height: 20)
                }

                Text(product.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                Text(product.displayPrice)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await service.purchase(product) }
        } label: {
            Group {
                if service.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    let key = service.trialDaysRemaining > 0 ? "paywall.cta.trial" : "paywall.cta.subscribe"
                    Text(L10n.tr(key))
                        .font(AppTheme.Typography.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.lg)
        }
        .disabled(service.isLoading || selectedProduct == nil)
    }

    private var restoreButton: some View {
        Button {
            Task { await service.restorePurchases() }
        } label: {
            Text(L10n.tr("paywall.restore"))
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Views/Paywall/PaywallView.swift
git commit -m "feat: add PaywallView with product picker, CTA, and restore"
```

---

## Task 5: Create TrialBannerView

**Files:**
- Create: `FreshCheck/Views/Dashboard/TrialBannerView.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Views/Dashboard/TrialBannerView.swift
import SwiftUI

struct TrialBannerView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundColor(.orange)
                Text(L10n.tr("trial.banner"))
                    .font(AppTheme.Typography.captionBold)
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.vertical, AppTheme.Spacing.sm)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(AppTheme.Radius.md)
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.xs)
        }
        .buttonStyle(.plain)
    }
}
```

**Step 2: Commit**

```bash
git add FreshCheck/Views/Dashboard/TrialBannerView.swift
git commit -m "feat: add TrialBannerView day-6 warning component"
```

---

## Task 6: Wire Paywall Gate into ContentView

**Files:**
- Modify: `FreshCheck/ContentView.swift`

**Step 1: Replace ContentView.swift**

```swift
// FreshCheck/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @Environment(SubscriptionService.self) private var subscriptionService

    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label(L10n.tr("tab.fridge"), systemImage: AppTheme.Icons.fridgeTab) }
            WasteStatsView()
                .tabItem { Label(L10n.tr("tab.stats"), systemImage: AppTheme.Icons.statsTab) }
        }
        .tint(AppTheme.Colors.accent)
        .task {
            let granted = await NotificationService.requestPermission()
            if granted {
                let message = NotificationService.buildDigestMessage(for: items)
                NotificationService.scheduleUsingSavedTime(message: message)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !hasSeenOnboarding },
            set: { _ in }
        )) {
            OnboardingView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { hasSeenOnboarding && !subscriptionService.isAccessAllowed },
            set: { _ in }
        )) {
            PaywallView(isDismissible: false)
        }
    }
}
```

**Key notes:**
- Onboarding gate takes priority — it's checked first. Only after onboarding is done does the paywall gate activate.
- Paywall `isDismissible: false` because trial has expired — user must subscribe or restore.
- Both gates use no-op setters because dismissal is controlled by the service/flag, not the binding.

**Step 2: Commit**

```bash
git add FreshCheck/ContentView.swift
git commit -m "feat: add paywall fullScreenCover gate in ContentView"
```

---

## Task 7: Wire Trial Banner into DashboardView

**Files:**
- Modify: `FreshCheck/Views/Dashboard/DashboardView.swift`

**Step 1: Add `@Environment` and `@State` for paywall sheet**

After the existing `@AppStorage` line (line 44), add:
```swift
@Environment(SubscriptionService.self) private var subscriptionService
@State private var showingPaywall = false
```

**Step 2: Add `TrialBannerView` to the VStack in body**

In the `VStack(spacing: AppTheme.Spacing.sm)` in `body`, add this BEFORE the streak banner:

```swift
if subscriptionService.trialDaysRemaining == 1 {
    TrialBannerView { showingPaywall = true }
}
```

**Step 3: Add paywall sheet**

After the existing `.sheet(item: $itemToEdit)` modifier, add:
```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView(isDismissible: true)
}
```

**Step 4: Commit**

```bash
git add FreshCheck/Views/Dashboard/DashboardView.swift
git commit -m "feat: show trial banner on day 6, tap opens dismissible PaywallView"
```

---

## Done Checklist

- [ ] 11 EN + 11 ZH localization keys added
- [ ] `SubscriptionService.shared` loads products on app launch
- [ ] `trialStartDate` set once on first launch, never resets
- [ ] `trialDaysRemaining` counts down correctly from 7
- [ ] `isAccessAllowed` is true during trial OR when subscribed
- [ ] Paywall fullScreenCover appears in ContentView when trial expired + not subscribed
- [ ] Paywall is non-dismissible after trial expiry
- [ ] Day-6 `TrialBannerView` appears in Dashboard only when `trialDaysRemaining == 1`
- [ ] Tapping banner opens dismissible `PaywallView` sheet
- [ ] Product picker shows monthly + annual cards
- [ ] Annual card shows savings % badge
- [ ] CTA says "Start 7-Day Free Trial" during trial, "Subscribe Now" after
- [ ] Restore Purchases calls `AppStore.sync()`
- [ ] Purchase errors shown in alert
- [ ] EN + ZH strings render correctly
