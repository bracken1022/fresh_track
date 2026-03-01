// FreshCheck/Views/Dashboard/DashboardView.swift
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    @Environment(\.modelContext) private var context
    @State private var showingAddFood = false

    private var activeItems: [FoodItem] {
        items.filter { $0.status != .consumed && $0.status != .wasted }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(activeItems) { item in
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
            }
            .listStyle(.insetGrouped)
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
                if activeItems.isEmpty {
                    ContentUnavailableView(
                        "Fridge is empty",
                        systemImage: AppTheme.Icons.fridgeTab,
                        description: Text("Tap the camera icon to add food.")
                    )
                }
            }
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
