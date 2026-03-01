// FreshCheck/Views/Camera/AnalysisResultView.swift
import SwiftUI

struct AnalysisResultView: View {
    @Bindable var vm: AddFoodViewModel
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Detected Food") {
                    HStack {
                        Text(vm.category.icon).font(.largeTitle)
                        TextField("Food name", text: $vm.name)
                    }
                    Picker("Category", selection: $vm.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.rawValue.capitalized)").tag(cat)
                        }
                    }
                }

                Section("Expiry Date") {
                    DatePicker("Expires", selection: $vm.expiryDate, displayedComponents: .date)
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: vm.confidenceSource == .ocr ? AppTheme.Icons.ocrSource : AppTheme.Icons.aiSource)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text(vm.confidenceSource == .ocr ? "Read from package" : "AI estimate")
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                if vm.isExpiredOnAdd {
                    Section {
                        Label("This item may already be expired.", systemImage: AppTheme.Icons.expiringStatus)
                            .foregroundColor(AppTheme.Colors.expiringSoon)
                    }
                }
            }
            .navigationTitle("Confirm Food Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: onConfirm)
                        .disabled(vm.name.isEmpty)
                }
            }
        }
    }
}
