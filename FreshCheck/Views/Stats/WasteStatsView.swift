// FreshCheck/Views/Stats/WasteStatsView.swift
import SwiftUI
import SwiftData
import Charts

struct WasteStatsView: View {
    @Query private var records: [WasteRecord]

    private var thisMonth: [WasteRecord] {
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
        return records.filter { $0.disposedDate >= start }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.tr("stats.section.month")) {
                    HStack {
                        statTile(title: L10n.tr("stats.logged"), value: thisMonth.count)
                        statTile(title: L10n.tr("stats.consumed"), value: thisMonth.filter { $0.outcome == .consumed }.count)
                        statTile(title: L10n.tr("stats.wasted"), value: thisMonth.filter { $0.outcome == .wasted }.count)
                    }
                    let pct = WasteStatsCalculator.wastePercentage(from: thisMonth)
                    Text("\(L10n.tr("stats.wasteRate")): \(Int(pct))%")
                        .font(AppTheme.Typography.headline)
                        .foregroundColor(pct > 30 ? AppTheme.Colors.expired : pct > 15 ? AppTheme.Colors.expiringSoon : AppTheme.Colors.fresh)
                }

                Section(L10n.tr("stats.section.byCategory")) {
                    let counts = WasteStatsCalculator.wastedCountByCategory(from: thisMonth)
                    Chart(FoodCategory.allCases, id: \.self) { category in
                        BarMark(
                            x: .value(L10n.tr("stats.chart.category"), category.localizedName),
                            y: .value(L10n.tr("stats.chart.count"), counts[category] ?? 0)
                        )
                        .foregroundStyle(AppTheme.Colors.expired.opacity(0.7))
                    }
                    .frame(height: 180)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.tr("stats.title"))
        }
    }

    private func statTile(title: String, value: Int) -> some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            Text("\(value)")
                .font(AppTheme.Typography.title)
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text(title)
                .font(AppTheme.Typography.caption)
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppTheme.Spacing.lg)
        .background(AppTheme.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }
}

// MARK: - Calculator (pure logic, testable)

enum WasteStatsCalculator {
    static func wastePercentage(from records: [WasteRecord]) -> Double {
        guard !records.isEmpty else { return 0 }
        let wasted = records.filter { $0.outcome == .wasted }.count
        return Double(wasted) / Double(records.count) * 100
    }

    static func wastedCountByCategory(from records: [WasteRecord]) -> [FoodCategory: Int] {
        records
            .filter { $0.outcome == .wasted }
            .reduce(into: [:]) { counts, record in
                counts[record.category, default: 0] += 1
            }
    }
}
