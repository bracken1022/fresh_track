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
            case .all: return "All"
            case .meats: return "Meats"
            case .vegetables: return "Vegetables"
            case .fruits: return "Fruits"
            case .others: return "Others"
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
    @Environment(\.modelContext) private var context
    @State private var showingAddFood = false
    @State private var selectedFilter: CategoryFilter = .all

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
                categoryFilters

                List {
                    ForEach(groupedItems, id: \.category) { group in
                        Section {
                            ForEach(group.items) { item in
                                FoodItemRow(item: item)
                                    .swipeActions(edge: .trailing) {
                                        Button("Wasted", role: .destructive) {
                                            dispose(item, outcome: .wasted)
                                        }
                                        .tint(AppTheme.Colors.wasted)
                                        Button("Consumed") {
                                            dispose(item, outcome: .consumed)
                                        }
                                        .tint(AppTheme.Colors.consumed)
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
            .navigationTitle("My Fridge")
            .toolbar {
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
            .overlay {
                if filteredItems.isEmpty {
                    ContentUnavailableView(
                        "Fridge is empty",
                        systemImage: AppTheme.Icons.fridgeTab,
                        description: Text("Tap the camera icon to add food.")
                    )
                }
            }
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
    }
}
