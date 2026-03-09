// FreshCheck/Views/Dashboard/EditFoodItemView.swift
import SwiftUI

struct EditFoodItemView: View {
    @Bindable var item: FoodItem
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("analysis.section.detected")) {
                    HStack {
                        Text(item.category.icon).font(.largeTitle)
                        TextField(L10n.tr("camera.field.foodName"), text: $item.name)
                    }
                    Picker(L10n.tr("analysis.field.category"), selection: $item.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.localizedName)").tag(cat)
                        }
                    }
                }

                Section(L10n.tr("analysis.section.expiry")) {
                    DatePicker(L10n.tr("analysis.field.expires"), selection: $item.expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle(L10n.tr("edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.save"), action: onDone)
                        .disabled(item.name.isEmpty)
                }
            }
        }
    }
}
