// FreshCheck/Views/Camera/AnalysisResultView.swift
import SwiftUI

struct AnalysisResultView: View {
    @Bindable var vm: AddFoodViewModel
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("analysis.section.detected")) {
                    HStack {
                        Text(vm.category.icon).font(.largeTitle)
                        TextField(L10n.tr("camera.field.foodName"), text: $vm.name)
                    }
                    Picker(L10n.tr("analysis.field.category"), selection: $vm.category) {
                        ForEach(FoodCategory.allCases, id: \.self) { cat in
                            Text("\(cat.icon) \(cat.localizedName)").tag(cat)
                        }
                    }
                }

                Section(L10n.tr("analysis.section.expiry")) {
                    DatePicker(L10n.tr("analysis.field.expires"), selection: $vm.expiryDate, displayedComponents: .date)
                    HStack(spacing: AppTheme.Spacing.xs) {
                        Image(systemName: vm.confidenceSource == .ocr ? AppTheme.Icons.ocrSource : AppTheme.Icons.aiSource)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Text(vm.confidenceSource == .ocr ? L10n.tr("analysis.source.ocr") : L10n.tr("analysis.source.ai"))
                            .font(AppTheme.Typography.caption)
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }

                if vm.isExpiredOnAdd {
                    Section {
                        Label(L10n.tr("analysis.warning.expired"), systemImage: AppTheme.Icons.expiringStatus)
                            .foregroundColor(AppTheme.Colors.expiringSoon)
                    }
                }
            }
            .navigationTitle(L10n.tr("analysis.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel"), action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.add"), action: onConfirm)
                        .disabled(vm.name.isEmpty)
                }
            }
        }
    }
}
