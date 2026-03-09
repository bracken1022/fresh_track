// FreshCheck/Services/SubscriptionService.swift
import StoreKit
import Observation

@Observable final class SubscriptionService {

    // MARK: - Constants
    static let shared = SubscriptionService()
    static let productIDs = ["foodai.pro.monthly", "foodai.pro.yearly"]
    static let trialStartKey = "trialStartDate"
    static let trialDurationDays = 7

    // MARK: - Published state
    var isSubscribed: Bool = false
    var products: [Product] = []
    var purchaseError: String? = nil
    var isLoading: Bool = false

    // MARK: - Computed
    var trialDaysRemaining: Int {
        guard let start = UserDefaults.standard.object(forKey: Self.trialStartKey) as? Date else {
            return Self.trialDurationDays
        }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        return max(0, Self.trialDurationDays - days)
    }

    var isAccessAllowed: Bool {
        isSubscribed || trialDaysRemaining > 0
    }

    // MARK: - Init
    private init() {}

    // MARK: - Load
    func load() async {
        await fetchProducts()
        await refreshEntitlement()
        listenForTransactions()
    }

    private func fetchProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("SubscriptionService: failed to fetch products — \(error)")
        }
    }

    func refreshEntitlement() async {
        var hasActive = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.revocationDate == nil {
                hasActive = true
            }
        }
        isSubscribed = hasActive
    }

    private func listenForTransactions() {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await tx.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
    }

    // MARK: - Purchase
    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let tx) = verification {
                    await tx.finish()
                    await refreshEntitlement()
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Savings badge
    func annualSavingsPct() -> Int? {
        guard let monthly = products.first(where: { $0.id == "foodai.pro.monthly" }),
              let annual  = products.first(where: { $0.id == "foodai.pro.yearly" }) else {
            return nil
        }
        let monthlyYear = monthly.price * Decimal(12)
        guard monthlyYear > 0 else { return nil }
        let saving = (monthlyYear - annual.price) / monthlyYear
        return Int(NSDecimalNumber(decimal: saving * 100).rounding(accordingToBehavior: nil).intValue)
    }
}
