# Onboarding Flow Design

**Date:** 2026-03-10
**Status:** Approved
**Scope:** Week 2 — 3-screen first-launch onboarding

---

## Problem

New users open the app with no context. Without guidance, they don't understand the core habit (log food at purchase/storage time), and the app's value is unclear before the first AI analysis.

## Goal

Give new users an emotional hook and a clear mental model in under 30 seconds, then immediately drop them into the first logging action.

---

## Design Decisions

- **Tone:** Emotional — lead with the problem, then show the solution
- **Notification permission:** Separate from onboarding (not included in this flow)
- **Exit action:** "Get Started" on screen 3 launches the camera immediately (AddFoodFlow)
- **Shows:** Once only, gated by `UserDefaults` flag `hasSeenOnboarding`

---

## Screens

| # | Icon | Headline | Subtitle |
|---|------|----------|---------|
| 1 | 🗑️ | "Food goes bad before you notice" | Every week, good food gets thrown away. It doesn't have to. |
| 2 | 📷 | "Just take a photo" | FreshCheck reads the expiry date — or estimates it for you. |
| 3 | 🔔 | "We'll remind you before it's too late" | A daily nudge before anything expires. |

---

## Architecture

### New Files
- `FreshCheck/Views/Onboarding/OnboardingView.swift` — parent container, manages page index
- `FreshCheck/Views/Onboarding/OnboardingPageView.swift` — reusable single page component

### Modified Files
- `FreshCheck/FreshCheckApp.swift` — check `hasSeenOnboarding` flag on launch
- `FreshCheck/en.lproj/Localizable.strings` — 6 new keys
- `FreshCheck/zh-Hans.lproj/Localizable.strings` — 6 new keys (Chinese translations)

### Data Flow
```
App launch
  → hasSeenOnboarding == false → OnboardingView
      → swipe through pages (dot indicator)
      → tap "Get Started" → set hasSeenOnboarding = true → open AddFoodFlow
  → hasSeenOnboarding == true  → ContentView (normal)
```

### UserDefaults Key
```
"hasSeenOnboarding" : Bool (default false)
```

---

## UI Spec

- **Layout:** Full-screen, no navigation bar
- **Background:** Solid color per page (green, blue, orange — matches AppTheme category colors)
- **Icon:** Large SF Symbol or emoji, centered
- **Headline:** AppTheme largeTitle, bold, white
- **Subtitle:** AppTheme body, white @ 80% opacity
- **Navigation:** Swipe gesture + dot indicator at bottom
- **CTA button:** "Get Started" shown only on page 3; "Next" arrow on pages 1–2
- **Skip:** No skip button (flow is <30 seconds, emotional pacing matters)

---

## Localization Keys

```
onboarding.page1.headline = "Food goes bad before you notice"
onboarding.page1.subtitle = "Every week, good food gets thrown away. It doesn't have to."
onboarding.page2.headline = "Just take a photo"
onboarding.page2.subtitle = "FreshCheck reads the expiry date — or estimates it for you."
onboarding.page3.headline = "We'll remind you before it's too late"
onboarding.page3.subtitle = "A daily nudge before anything expires."
onboarding.cta.getStarted = "Get Started"
onboarding.cta.next = "Next"
```

---

## Out of Scope

- Notification permission request (handled separately)
- User account / sign-in
- Tutorial overlay on Dashboard
- Ability to replay onboarding from Settings
