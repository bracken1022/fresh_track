# Monetization Design — Subscription with 7-Day Free Trial

**Date:** 2026-03-10
**Status:** Approved
**Scope:** StoreKit 2 subscription, 7-day trial, day-6 warning banner, hard paywall gate

---

## Model

- **Type:** Auto-renewable subscription (monthly + annual)
- **Trial:** 7 days free, starts on first app launch
- **Products:** `foodai.pro.monthly`, `foodai.pro.yearly`
- **Paywall trigger:** Proactive warning on day 6; full lock when trial expires and not subscribed

---

## Access Logic

```
trialStartDate  = UserDefaults["trialStartDate"]  (set once on first launch)
trialDaysRemaining = 7 - daysSince(trialStartDate)
isAccessAllowed = isSubscribed || trialDaysRemaining > 0
```

- Days 1–6: full access, no UI interruption
- Day 6 (1 day remaining): warning banner in Dashboard, tapping opens PaywallView
- Day 7+: `PaywallView` shown as non-dismissible `.fullScreenCover` over ContentView

---

## Architecture

### New Files
- `FreshCheck/Services/SubscriptionService.swift` — StoreKit 2 singleton, entitlement + trial state
- `FreshCheck/Views/Paywall/PaywallView.swift` — full-screen paywall sheet
- `FreshCheck/Views/Dashboard/TrialBannerView.swift` — day-6 warning banner

### Modified Files
- `FreshCheck/FreshCheckApp.swift` — set `trialStartDate` on first launch, inject `SubscriptionService` into environment
- `FreshCheck/ContentView.swift` — add `.fullScreenCover` for expired + unsubscribed state
- `FreshCheck/Views/Dashboard/DashboardView.swift` — show `TrialBannerView` when `trialDaysRemaining == 1`
- `FreshCheck/en.lproj/Localizable.strings` — paywall + trial strings
- `FreshCheck/zh-Hans.lproj/Localizable.strings` — Chinese translations

---

## SubscriptionService

```swift
@Observable final class SubscriptionService {
    var isSubscribed: Bool = false
    var trialDaysRemaining: Int = 7
    var products: [Product] = []

    static let shared = SubscriptionService()
    static let productIDs = ["foodai.pro.monthly", "foodai.pro.yearly"]
    static let trialStartKey = "trialStartDate"
    static let trialDurationDays = 7

    var isAccessAllowed: Bool { isSubscribed || trialDaysRemaining > 0 }
}
```

**On init:**
1. Load products via `Product.products(for: productIDs)`
2. Check existing transactions via `Transaction.currentEntitlements`
3. Compute `trialDaysRemaining` from `UserDefaults[trialStartKey]`
4. Start `Transaction.updates` listener task

**`purchase(_ product: Product)`** — calls `product.purchase()`, handles `.success`, `.userCancelled`, `.pending`

**`restorePurchases()`** — calls `AppStore.sync()`

---

## PaywallView

- Full-screen, non-dismissible after trial expiry; has X button during trial
- Headline: "Keep your fridge fresh"
- 3 feature bullets: AI expiry detection, daily reminders, waste tracking
- Monthly / Annual `Picker` toggle
- Annual shows "Save 40%" badge (calculated at runtime from product prices)
- CTA button: "Start 7-Day Free Trial" (day 1–6) or "Subscribe" (expired)
- Subtitle below CTA: price + billing cadence from StoreKit product
- "Restore Purchases" text button at bottom
- Error alert for failed purchases

---

## TrialBannerView

- Shown in DashboardView only when `trialDaysRemaining == 1`
- Text: "Your free trial ends tomorrow — subscribe to keep access."
- Tapping the banner opens PaywallView as a sheet
- Styled in orange (warning), dismissible

---

## Trial Start Date

Set in `FreshCheckApp.init()` or `.onAppear`:
```swift
if UserDefaults.standard.object(forKey: SubscriptionService.trialStartKey) == nil {
    UserDefaults.standard.set(Date(), forKey: SubscriptionService.trialStartKey)
}
```

This ensures the trial clock starts on first launch and never resets.

---

## Localization Keys

```
"paywall.headline" = "Keep your fridge fresh"
"paywall.feature1" = "AI reads expiry dates from photos"
"paywall.feature2" = "Daily reminders before food expires"
"paywall.feature3" = "Track your food waste over time"
"paywall.cta.trial" = "Start 7-Day Free Trial"
"paywall.cta.subscribe" = "Subscribe Now"
"paywall.restore" = "Restore Purchases"
"paywall.save.badge" = "Save {pct}%"
"trial.banner" = "Your free trial ends tomorrow — subscribe to keep access."
```

---

## Out of Scope
- Paywall A/B testing
- Promotional offers / promo codes
- Family sharing support
- Grace period handling for failed renewals
- Server-side receipt validation
