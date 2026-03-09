# Onboarding Flow Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Show a 3-screen emotional onboarding on first launch only, ending with the camera opening so the user logs their first food item immediately.

**Architecture:** `ContentView` presents `OnboardingView` as a `.fullScreenCover` when `hasSeenOnboarding` is false. Inside onboarding, "Get Started" opens `AddFoodFlow` as a sheet. When the user finishes (or cancels) adding food, `hasSeenOnboarding` is set to `true`, which auto-dismisses the full-screen cover and lands the user on the Dashboard.

**Tech Stack:** SwiftUI, `@AppStorage` (UserDefaults), `TabView` with `.tabViewStyle(.page)` for swipe navigation, existing `AddFoodFlow`, `L10n`, `AppTheme`.

---

## Task 1: Add Localization Keys

**Files:**
- Modify: `FreshCheck/en.lproj/Localizable.strings`
- Modify: `FreshCheck/zh-Hans.lproj/Localizable.strings`

**Step 1: Add English keys**

Open `FreshCheck/en.lproj/Localizable.strings` and append at the end:

```
"onboarding.page1.headline" = "Food goes bad before you notice";
"onboarding.page1.subtitle" = "Every week, good food gets thrown away. It doesn't have to.";
"onboarding.page2.headline" = "Just take a photo";
"onboarding.page2.subtitle" = "FreshCheck reads the expiry date — or estimates it for you.";
"onboarding.page3.headline" = "We'll remind you before it's too late";
"onboarding.page3.subtitle" = "A daily nudge before anything expires.";
"onboarding.cta.next" = "Next";
"onboarding.cta.getStarted" = "Get Started";
```

**Step 2: Add Chinese keys**

Open `FreshCheck/zh-Hans.lproj/Localizable.strings` and append at the end:

```
"onboarding.page1.headline" = "食物悄悄变质，你却浑然不觉";
"onboarding.page1.subtitle" = "每周都有好食物被白白扔掉，其实完全可以避免。";
"onboarding.page2.headline" = "拍张照片就够了";
"onboarding.page2.subtitle" = "FreshCheck 自动读取保质期，或智能估算新鲜时长。";
"onboarding.page3.headline" = "过期前，我们会提醒你";
"onboarding.page3.subtitle" = "每天一条提醒，让食物不再浪费。";
"onboarding.cta.next" = "下一步";
"onboarding.cta.getStarted" = "开始使用";
```

**Step 3: Build to verify no missing key warnings**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

**Step 4: Commit**

```bash
git add FreshCheck/en.lproj/Localizable.strings FreshCheck/zh-Hans.lproj/Localizable.strings
git commit -m "feat: add onboarding localization keys (EN + ZH)"
```

---

## Task 2: Create OnboardingPageView

**Files:**
- Create: `FreshCheck/Views/Onboarding/OnboardingPageView.swift`

**Step 1: Create the folder and file**

Create directory `FreshCheck/Views/Onboarding/` then create `OnboardingPageView.swift`:

```swift
// FreshCheck/Views/Onboarding/OnboardingPageView.swift
import SwiftUI

struct OnboardingPageView: View {
    let icon: String          // SF Symbol name
    let headline: String
    let subtitle: String
    let backgroundColor: Color

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: AppTheme.Spacing.xxl) {
                Spacer()

                Image(systemName: icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                VStack(spacing: AppTheme.Spacing.lg) {
                    Text(headline)
                        .font(AppTheme.Typography.largeTitle)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(AppTheme.Typography.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppTheme.Spacing.xxl)
                }

                Spacer()
                Spacer()
            }
        }
    }
}
```

**Step 2: Build to verify it compiles**

In Xcode: `Cmd+B`
Expected: Build succeeds.

**Step 3: Commit**

```bash
git add FreshCheck/Views/Onboarding/OnboardingPageView.swift
git commit -m "feat: add OnboardingPageView reusable component"
```

---

## Task 3: Create OnboardingView

**Files:**
- Create: `FreshCheck/Views/Onboarding/OnboardingView.swift`

**Step 1: Create the file**

```swift
// FreshCheck/Views/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var showingAddFood = false

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
        }) {
            AddFoodFlow()
        }
    }

    private var bottomControls: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()

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

**Key behavior notes:**
- `TabView` with `.page` style gives the swipe gesture and dot indicator for free
- `onDismiss` of the AddFoodFlow sheet sets `hasSeenOnboarding = true` — this fires whether the user adds food or cancels, so onboarding is never shown again
- Colors are custom green/blue/orange matching app identity

**Step 2: Build to verify it compiles**

In Xcode: `Cmd+B`
Expected: Build succeeds with no errors.

**Step 3: Commit**

```bash
git add FreshCheck/Views/Onboarding/OnboardingView.swift
git commit -m "feat: add OnboardingView with swipeable pages and Get Started flow"
```

---

## Task 4: Wire Onboarding into ContentView

**Files:**
- Modify: `FreshCheck/ContentView.swift`

**Step 1: Add the AppStorage flag and fullScreenCover**

Replace the current `ContentView.swift` body with:

```swift
// FreshCheck/ContentView.swift
import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var items: [FoodItem]
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

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
    }
}
```

**What changed:** Added `@AppStorage("hasSeenOnboarding")` and a `.fullScreenCover` that shows `OnboardingView` whenever the flag is false. The binding's `set` is a no-op because `OnboardingView` manages the flag directly via its own `@AppStorage`.

**Step 2: Build and run on simulator**

In Xcode: `Cmd+R` on iPhone simulator.

**Expected first launch:**
1. Onboarding screen 1 appears (green background, trash icon)
2. Swipe left or tap "Next" → screen 2 (blue, camera icon)
3. Swipe left or tap "Next" → screen 3 (orange, bell icon)
4. Tap "Get Started" → camera sheet opens
5. Take/cancel photo → camera dismisses → onboarding closes → Dashboard appears

**Step 3: Test that onboarding does not reappear**

Kill the app and relaunch.
Expected: Dashboard appears directly, no onboarding.

**Step 4: Reset onboarding for testing (if needed)**

In Xcode → Run on simulator → Device menu → "Erase All Content and Settings" on the simulator. Or add a temporary debug button in Dashboard that resets the flag:

```swift
// Temporary debug only — remove before shipping
Button("Reset Onboarding") {
    UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
}
```

**Step 5: Test language switching**

Switch app language to Chinese (globe icon on Dashboard).
Kill and relaunch.
Expected: Onboarding shows on next fresh install; all text in Chinese.

**Step 6: Commit**

```bash
git add FreshCheck/ContentView.swift
git commit -m "feat: show onboarding on first launch via fullScreenCover"
```

---

## Task 5: Add Files to Xcode Project

**Important:** In Xcode, newly created `.swift` files in the filesystem may not be automatically added to the build target.

**Step 1: Add files to target**

In Xcode's Project Navigator:
1. Right-click `Views` folder → "Add Files to FreshCheck..."
2. Select the `Onboarding` folder
3. Ensure "Add to targets: FreshCheck" is checked
4. Click Add

Alternatively, drag the `Onboarding` folder from Finder into the Project Navigator.

**Step 2: Verify target membership**

Click `OnboardingView.swift` in Project Navigator → File Inspector (right panel) → confirm "Target Membership: FreshCheck" is checked. Repeat for `OnboardingPageView.swift`.

**Step 3: Final build**

`Cmd+B` — Expected: Clean build with no errors or warnings.

**Step 4: Final commit (if any Xcode project file changes)**

```bash
git add FreshCheck.xcodeproj/project.pbxproj
git commit -m "chore: add Onboarding files to Xcode build target"
```

---

## Done Checklist

- [ ] EN + ZH localization keys added
- [ ] `OnboardingPageView` renders correctly on all 3 pages
- [ ] Swipe between pages works
- [ ] Dot indicator updates on swipe and button tap
- [ ] "Next" button advances pages
- [ ] "Get Started" opens camera (AddFoodFlow sheet)
- [ ] After camera dismiss (add OR cancel), onboarding closes
- [ ] Relaunching app skips onboarding
- [ ] Chinese language shows translated copy
- [ ] No build warnings
