# FreshCheck — Design Document
**Date:** 2026-02-28
**Status:** Approved

---

## Overview

FreshCheck is an iOS app that helps a single user track the expiry dates of food stored in their fridge. The user takes a photo of food; the app automatically identifies the item and sets an expiry date using Claude Vision API (OCR for packaged items, shelf-life estimates for fresh produce). A daily digest notification and a color-coded dashboard keep the user aware of what's about to go bad. Waste history gives users insight into food they throw away over time.

---

## Goals

- Minimize friction — photo capture is the primary (and preferred) input method
- Cover all fridge content types: fresh produce, meats, dairy, and packaged goods
- Notify users proactively without being spammy (one daily digest)
- Motivate less food waste through visible waste history

---

## Architecture

```
┌─────────────────────────────────────────┐
│              iOS App (SwiftUI)          │
│                                         │
│  ┌──────────┐  ┌──────────┐  ┌───────┐ │
│  │ Camera   │  │Dashboard │  │Waste  │ │
│  │ Capture  │  │(Fridge)  │  │Stats  │ │
│  └────┬─────┘  └────┬─────┘  └───────┘ │
│       │              │                  │
│  ┌────▼──────────────▼────────────────┐ │
│  │         SwiftData (Local DB)       │ │
│  └────────────────────────────────────┘ │
└───────────────┬─────────────────────────┘
                │ HTTPS (photo + prompt)
        ┌───────▼────────┐
        │ Claude Vision  │
        │     API        │
        └────────────────┘
```

**Technology choices:**
| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Local persistence | SwiftData |
| Photo analysis | Claude Vision API (claude-sonnet-4-6) |
| Notifications | UserNotifications framework |

---

## Data Model

```swift
FoodItem
├── id: UUID
├── name: String                  // "Broccoli", "Whole Milk"
├── category: FoodCategory        // .produce, .meat, .dairy, .packaged, .other
├── photoURL: String              // local file path (Documents/food-images/)
├── addedDate: Date               // when user logged it
├── expiryDate: Date              // from Claude (OCR or shelf-life estimate)
├── confidenceSource: Source      // .ocr | .shelfLife
└── status: ItemStatus            // .fresh | .expiringSoon | .expired | .consumed | .wasted

WasteRecord
├── id: UUID
├── foodItemName: String          // denormalized — source item may be deleted
├── category: FoodCategory
├── addedDate: Date
├── expiryDate: Date
├── disposedDate: Date
└── outcome: Outcome              // .consumed | .wasted
```

**Status thresholds:**
- `.fresh` — more than 3 days to expiry
- `.expiringSoon` — 0–3 days to expiry
- `.expired` — past expiry date

---

## Screens & User Flows

### Screen 1 — Dashboard (Fridge View)
Color-coded list of all active food items, sorted by expiry date (soonest first). Each row shows: photo thumbnail, food name, category icon, days remaining, and a status color badge (green/yellow/red). Swipe left reveals "Consumed" and "Wasted" actions.

### Screen 2 — Add Food (Camera Flow)
```
[Camera opens]
     ↓
[User takes photo]
     ↓
[Photo sent to Claude API]
     ↓
[Loading state: "Analyzing your food..."]
     ↓
[Result card]:
  • Detected name + category
  • Expiry date
  • Source badge: "AI estimate" | "From package"
  • [Confirm] [Edit date]
     ↓
[Saved to SwiftData → Dashboard]
```

### Screen 3 — Waste Stats
Monthly summary: total items logged, consumed count, wasted count, waste percentage. Bar chart broken down by food category. No date range filtering in v1.

### Screen 4 — Notifications
Daily digest push notification at a user-set time (default 8am):
> "3 items in your fridge expire within 3 days: broccoli, chicken breast, yogurt."

No dedicated settings screen in v1 — notification time configurable via iOS Settings.

---

## Claude API Integration

### Prompt

```
You are analyzing a photo of food that will be stored in a fridge.

1. Identify the food item(s) visible in the photo.
2. If a printed expiry/best-before date is visible on packaging, extract it.
3. If no printed date is visible, estimate shelf life in the fridge based on
   food safety standards.

Respond ONLY with JSON in this exact format:
{
  "name": "Broccoli",
  "category": "produce",
  "expiryDate": "2026-03-05",
  "confidenceSource": "shelfLife",
  "shelfLifeDays": 5
}

category must be one of: produce | meat | dairy | packaged | other
confidenceSource must be one of: ocr | shelfLife
shelfLifeDays is null when confidenceSource is ocr
```

### Photo handling
- Resize to max 1024px before sending (cost and latency)
- Store locally in `Documents/food-images/` only
- Delete photo when item is marked consumed or wasted

### Error handling
| Scenario | Behavior |
|---|---|
| Claude cannot identify item | Show manual name input field |
| No internet connection | Block camera flow with "Internet required" message |
| API timeout (>10s) | Fall back to manual name input |
| Expiry date in the past | Warn user, let them confirm or discard |
| Implausible shelf life (>30 days for fresh produce) | Cap at 30 days |

---

## Edge Cases

- **Multiple items in photo:** Log only the most prominent detected item. Multi-item logging deferred to v2.
- **Duplicate items:** No deduplication. Two blocks of cheese = two entries. Intentional.
- **Photo storage cleanup:** Photos deleted automatically when item is disposed (consumed/wasted).

---

## Permissions Required

| Permission | Required | Prompt timing |
|---|---|---|
| Camera | Yes | On first "Add Food" tap |
| Push notifications | No (optional) | Once on first app launch |

---

## Out of Scope (v1)

- Multi-user / household sharing
- Barcode scanning
- On-device ML (CoreML)
- Date range filtering in waste stats
- Freezer tracking
- Grocery list generation

---

## Success Criteria

- User can photograph food and have it logged in under 10 seconds
- Expiry dates are accurate for common fridge items (produce, meat, dairy, packaged)
- Daily notification lists expiring items correctly
- Waste stats accurately reflect consumed vs. wasted items over time
