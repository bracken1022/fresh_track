// FreshCheck/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    private enum CategoryFilter: String, CaseIterable, Identifiable {
        case all
        case meats
        case vegetables
        case fruits
        case others

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return L10n.tr("dashboard.filter.all")
            case .meats: return L10n.tr("dashboard.filter.meats")
            case .vegetables: return L10n.tr("dashboard.filter.vegetables")
            case .fruits: return L10n.tr("dashboard.filter.fruits")
            case .others: return L10n.tr("dashboard.filter.others")
            }
        }

        var icon: String {
            switch self {
            case .all: return "🧺"
            case .meats: return FoodDisplayCategory.meats.icon
            case .vegetables: return FoodDisplayCategory.vegetables.icon
            case .fruits: return FoodDisplayCategory.fruits.icon
            case .others: return FoodDisplayCategory.others.icon
            }
        }
    }

    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    @Query private var allItems: [FoodItem]  // all statuses — consumed/wasted intentionally count as "ever logged"
    @AppStorage(StreakService.currentStreakKey) private var currentStreak: Int = 0
    @Environment(\.modelContext) private var context
    @State private var showingAddFood = false
    @State private var showingReminderSettings = false
    @State private var selectedFilter: CategoryFilter = .all
    @State private var itemToEdit: FoodItem? = nil
    @AppStorage(L10n.appLanguageStorageKey) private var appLanguageRawValue: String = AppLanguage.system.rawValue
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showingPaywall = false

    private var activeItems: [FoodItem] {
        items.filter { $0.status != .consumed && $0.status != .wasted }
    }

    private var filteredItems: [FoodItem] {
        switch selectedFilter {
        case .all:
            return activeItems
        case .meats:
            return activeItems.filter { $0.displayCategory == .meats }
        case .vegetables:
            return activeItems.filter { $0.displayCategory == .vegetables }
        case .fruits:
            return activeItems.filter { $0.displayCategory == .fruits }
        case .others:
            return activeItems.filter { $0.displayCategory == .others }
        }
    }

    private var groupedItems: [(category: FoodDisplayCategory, items: [FoodItem])] {
        FoodDisplayCategory.allCases.compactMap { category in
            let matching = filteredItems.filter { $0.displayCategory == category }
            return matching.isEmpty ? nil : (category, matching)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.Spacing.sm) {
                if subscriptionService.trialDaysRemaining == 1 {
                    TrialBannerView { showingPaywall = true }
                }
                if currentStreak >= 2 {
                    StreakBannerView(streak: currentStreak)
                }
                categoryFilters

                List {
                    ForEach(groupedItems, id: \.category) { group in
                        Section {
                            ForEach(group.items) { item in
                                FoodItemRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button(L10n.tr("dashboard.action.wasted"), role: .destructive) {
                                            dispose(item, outcome: .wasted)
                                        }
                                        .tint(AppTheme.Colors.wasted)
                                        Button(L10n.tr("dashboard.action.consumed")) {
                                            dispose(item, outcome: .consumed)
                                        }
                                        .tint(AppTheme.Colors.consumed)
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button(L10n.tr("dashboard.action.edit")) {
                                            itemToEdit = item
                                        }
                                        .tint(AppTheme.Colors.accent)
                                    }
                            }
                        } header: {
                            categoryHeader(for: group.category)
                        }
                        .textCase(nil)
                        .listRowBackground(AppTheme.Colors.surface)
                        .headerProminence(.increased)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle(L10n.tr("dashboard.title"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    languageMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingReminderSettings = true
                    } label: {
                        Image(systemName: "bell.badge")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: AppTheme.Icons.cameraTab)
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                AddFoodFlow()
            }
            .sheet(isPresented: $showingReminderSettings) {
                NotificationSettingsView()
            }
            .sheet(item: $itemToEdit) { item in
                EditFoodItemView(item: item) { itemToEdit = nil }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(isDismissible: true)
            }
            .overlay {
                if filteredItems.isEmpty {
                    let variant: EmptyStateView.Variant = allItems.isEmpty ? .neverLogged : .allCleared
                    EmptyStateView(variant: variant) {
                        showingAddFood = true
                    }
                }
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            ForEach(AppLanguage.allCases) { language in
                Button {
                    appLanguageRawValue = language.rawValue
                } label: {
                    if appLanguageRawValue == language.rawValue {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            Image(systemName: "globe")
        }
    }

    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ForEach(CategoryFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text("\(filter.icon) \(filter.title)")
                            .font(AppTheme.Typography.captionBold)
                            .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.vertical, AppTheme.Spacing.sm)
                            .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surface)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, AppTheme.Spacing.xs)
        }
    }

    private func categoryHeader(for category: FoodDisplayCategory) -> some View {
        let color = AppTheme.Colors.forDisplayCategory(category)
        return HStack(spacing: AppTheme.Spacing.sm) {
            Text(category.icon)
            Text(category.title)
                .font(AppTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(color)
        }
    }

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
}
