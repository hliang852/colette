import SwiftUI
import SwiftData

/// The Home tab: a combined overview of grocery + dining-out spending, with
/// a stacked monthly/daily chart and a list of the most recent receipts.
struct HomeView: View {
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    /// Mirrors the existing USD/HKD picker on the per-category tabs.
    @State private var displayCurrency = "USD"
    @State private var granularity: SpendingGranularity = .monthly

    private func inDisplayCurrency(_ receipt: Receipt) -> Double {
        CurrencyConverter.convert(receipt.total, from: receipt.currency, to: displayCurrency)
    }

    private var chartData: [PeriodSpending] {
        let all = aggregateSpending(receipts, by: granularity, convert: inDisplayCurrency)
        switch granularity {
        case .monthly: return Array(all.suffix(6))   // last 6 months
        case .daily: return Array(all.suffix(14))    // last 14 days
        }
    }

    /// This month's total, broken down by category, in displayCurrency.
    private var monthToDateByCategory: [ReceiptCategory: Double] {
        var totals: [ReceiptCategory: Double] = [:]
        for receipt in receipts where receipt.monthKey == currentMonthKey {
            totals[receipt.category, default: 0] += inDisplayCurrency(receipt)
        }
        return totals
    }

    private var monthToDateTotal: Double {
        monthToDateByCategory.values.reduce(0, +)
    }

    private var recentReceipts: [Receipt] {
        Array(receipts.prefix(5))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                    granularityPicker
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)

                    if !chartData.isEmpty {
                        HomeSpendingChart(data: chartData, displayCurrency: displayCurrency, granularity: granularity)
                            .frame(height: 220)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                if !recentReceipts.isEmpty {
                    Section("Recent") {
                        ForEach(recentReceipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                receiptRow(receipt)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Overview")
            .overlay {
                if receipts.isEmpty {
                    ContentUnavailableView(
                        "No receipts yet",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Tap Scan to add your first receipt.")
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var summaryHeader: some View {
        VStack(spacing: 6) {
            // "Spent this month" is the hero number — the category breakdown
            // sits below it as a smaller secondary line, not a parallel card.
            Text("Spent this month")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(monthToDateTotal, format: .currency(code: displayCurrency))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(monthLabel(from: currentMonthKey))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                ForEach(ReceiptCategory.allCases) { category in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(category.color)
                            .frame(width: 8, height: 8)
                        Text(category.rawValue)
                        Text(monthToDateByCategory[category] ?? 0, format: .currency(code: displayCurrency))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 4)

            Picker("Display currency", selection: $displayCurrency) {
                ForEach(CurrencyConverter.supported, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var granularityPicker: some View {
        Picker("View by", selection: $granularity) {
            Text("Monthly").tag(SpendingGranularity.monthly)
            Text("Daily").tag(SpendingGranularity.daily)
        }
        .pickerStyle(.segmented)
    }

    private func receiptRow(_ receipt: Receipt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.storeName.isEmpty ? "Receipt" : receipt.storeName)
                HStack(spacing: 4) {
                    Image(systemName: receipt.category.icon)
                    Text(receipt.date, format: .dateTime.month().day())
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(inDisplayCurrency(receipt), format: .currency(code: displayCurrency))
        }
    }
}

extension ReceiptCategory {
    var color: Color {
        switch self {
        case .grocery: return .blue
        case .diningOut: return .orange
        }
    }
}
