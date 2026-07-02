import SwiftUI
import SwiftData

/// Shows one category's (Groceries or Dining Out) receipts, with a summary
/// header, a Groceries-vs-Dining-Out split bar, and a daily spending chart at
/// the top, then the receipts themselves — current month flat, older ones
/// collapsible by month/year. Used for both the Groceries and Dining Out
/// tabs — only the `category` filter differs. Goal/budget setting lives only
/// on the Home tab now.
struct ReceiptListView: View {
    let category: ReceiptCategory

    @Environment(\.modelContext) private var context
    @Query(sort: \Receipt.date, order: .reverse) private var allReceipts: [Receipt]

    @State private var displayCurrency = "USD"

    private var receipts: [Receipt] {
        allReceipts.filter { $0.category == category }
    }

    private func inDisplayCurrency(_ receipt: Receipt) -> Double {
        CurrencyConverter.convert(receipt.total, from: receipt.currency, to: displayCurrency)
    }

    private func total(of receipts: [Receipt]) -> Double {
        receipts.reduce(0) { $0 + inDisplayCurrency($1) }
    }

    /// Last 14 days of spending for this category, in displayCurrency.
    private var chartData: [PeriodSpending] {
        let all = aggregateSpending(receipts, by: .daily, convert: inDisplayCurrency)
        return Array(all.suffix(14))
    }

    private var monthToDateTotal: Double {
        receipts
            .filter { $0.monthKey == currentMonthKey }
            .reduce(0) { $0 + inDisplayCurrency($1) }
    }

    /// This month's total for the given category (not just this tab's own
    /// category) in displayCurrency — feeds the Groceries-vs-Dining-Out split
    /// bar, which needs both sides regardless of which tab you're on.
    private func monthToDateTotal(for category: ReceiptCategory) -> Double {
        allReceipts
            .filter { $0.category == category && $0.monthKey == currentMonthKey }
            .reduce(0) { $0 + inDisplayCurrency($1) }
    }

    /// Receipts split into: current month (flat), older months this year
    /// (collapsible), and prior years (collapsible, with collapsible months
    /// inside).
    private var grouped: (currentMonth: [Receipt], otherMonthsThisYear: [MonthGroup], otherYears: [YearGroup]) {
        groupReceiptsForDisplay(receipts)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)

                    CategorySplitBar(
                        groceryTotal: monthToDateTotal(for: .grocery),
                        diningTotal: monthToDateTotal(for: .diningOut)
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    if !chartData.isEmpty {
                        SpendingChart(data: chartData, displayCurrency: displayCurrency, barColor: category.color)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                if !grouped.currentMonth.isEmpty {
                    Section("This Month") {
                        ForEach(grouped.currentMonth) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                receiptRow(receipt)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { context.delete(grouped.currentMonth[index]) }
                        }
                    }
                }

                ForEach(grouped.otherMonthsThisYear) { month in
                    Section {
                        DisclosureGroup {
                            ForEach(month.receipts) { receipt in
                                NavigationLink {
                                    ReceiptDetailView(receipt: receipt)
                                } label: {
                                    receiptRow(receipt)
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets { context.delete(month.receipts[index]) }
                            }
                        } label: {
                            HStack {
                                Text(month.label)
                                Spacer()
                                Text(total(of: month.receipts), format: .currency(code: displayCurrency))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(grouped.otherYears) { year in
                    Section {
                        DisclosureGroup {
                            ForEach(year.months) { month in
                                DisclosureGroup {
                                    ForEach(month.receipts) { receipt in
                                        NavigationLink {
                                            ReceiptDetailView(receipt: receipt)
                                        } label: {
                                            receiptRow(receipt)
                                        }
                                    }
                                    .onDelete { offsets in
                                        for index in offsets { context.delete(month.receipts[index]) }
                                    }
                                } label: {
                                    HStack {
                                        Text(month.label)
                                        Spacer()
                                        Text(total(of: month.receipts), format: .currency(code: displayCurrency))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(year.label)
                                Spacer()
                                Text(total(of: year.months.flatMap(\.receipts)), format: .currency(code: displayCurrency))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(category.rawValue)
            .overlay {
                if receipts.isEmpty {
                    ContentUnavailableView(
                        "No receipts yet",
                        systemImage: category.icon,
                        description: Text("Tap Scan to add your first receipt.")
                    )
                }
            }
        }
    }

    // MARK: - Subviews

    private var summaryHeader: some View {
        VStack(spacing: 6) {
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

    private func receiptRow(_ receipt: Receipt) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(receipt.storeName.isEmpty ? "Receipt" : receipt.storeName)
                HStack(spacing: 4) {
                    Text(receipt.date, format: .dateTime.month().day())
                    Text("· \(receipt.currency)")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(inDisplayCurrency(receipt), format: .currency(code: displayCurrency))
        }
    }
}
