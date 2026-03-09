// FreshCheck/Views/Paywall/PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(SubscriptionService.self) private var service
    @Environment(\.dismiss) private var dismiss

    let isDismissible: Bool

    @State private var selectedProductID: String = "foodai.pro.yearly"

    private var selectedProduct: Product? {
        service.products.first { $0.id == selectedProductID }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.xxl) {
                    header
                    features
                    productPicker
                    ctaButton
                    restoreButton
                }
                .padding(AppTheme.Spacing.xl)
                .padding(.top, AppTheme.Spacing.xxl)
            }

            if isDismissible {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(AppTheme.Spacing.lg)
            }
        }
        .alert(L10n.tr("paywall.error.title"), isPresented: Binding(
            get: { service.purchaseError != nil },
            set: { if !$0 { service.purchaseError = nil } }
        )) {
            Button(L10n.tr("common.ok"), role: .cancel) { service.purchaseError = nil }
        } message: {
            Text(service.purchaseError ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: AppTheme.Icons.fridgeTab)
                .font(.system(size: 56))
                .foregroundColor(AppTheme.Colors.accent)
            Text(L10n.tr("paywall.headline"))
                .font(AppTheme.Typography.largeTitle)
                .multilineTextAlignment(.center)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            featureRow(icon: "camera.viewfinder", key: "paywall.feature1")
            featureRow(icon: "bell.fill",         key: "paywall.feature2")
            featureRow(icon: "chart.bar.fill",    key: "paywall.feature3")
        }
    }

    private func featureRow(icon: String, key: String) -> some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.Colors.accent)
                .frame(width: 24)
            Text(L10n.tr(key))
                .font(AppTheme.Typography.body)
        }
    }

    private var productPicker: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ForEach(service.products, id: \.id) { product in
                productCard(product)
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isSelected = selectedProductID == product.id
        let isAnnual = product.id == "foodai.pro.yearly"
        let savingsPct = service.annualSavingsPct()

        return Button { selectedProductID = product.id } label: {
            VStack(spacing: AppTheme.Spacing.sm) {
                if isAnnual, let pct = savingsPct, pct > 0 {
                    Text(L10n.tr("paywall.save.badge").replacingOccurrences(of: "{pct}", with: "\(pct)"))
                        .font(AppTheme.Typography.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, AppTheme.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.accent)
                        .cornerRadius(AppTheme.Radius.sm)
                } else {
                    Spacer().frame(height: 20)
                }

                Text(product.displayName)
                    .font(AppTheme.Typography.headline)
                    .foregroundColor(isSelected ? .white : AppTheme.Colors.textPrimary)
                Text(product.displayPrice)
                    .font(AppTheme.Typography.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.85) : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background(isSelected ? AppTheme.Colors.accent : AppTheme.Colors.surface)
            .cornerRadius(AppTheme.Radius.lg)
        }
        .buttonStyle(.plain)
    }

    private var ctaButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            Task { await service.purchase(product) }
        } label: {
            Group {
                if service.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    let key = service.trialDaysRemaining > 0 ? "paywall.cta.trial" : "paywall.cta.subscribe"
                    Text(L10n.tr(key))
                        .font(AppTheme.Typography.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.accent)
            .cornerRadius(AppTheme.Radius.lg)
        }
        .disabled(service.isLoading || selectedProduct == nil)
    }

    private var restoreButton: some View {
        Button {
            Task { await service.restorePurchases() }
        } label: {
            Text(L10n.tr("paywall.restore"))
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}
