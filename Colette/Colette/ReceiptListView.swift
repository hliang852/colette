import SwiftUI
import SwiftData

/// Shows one category's (Groceries or Dining Out) receipts grouped by month,
/// with a summary header and monthly bar chart at the top. Used for both the
/// Groceries and Dining Out tabs — only the `category` filter differs.
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

    private var months: [MonthSpending] {
        Dictionary(grouping: receipts, by: { $0.monthKey })
            .map { key, recs in
                MonthSpending(
                    id: key,
                    label: monthLabel(from: key),
                    date: firstOfMonth(from: key),
                    total: recs.reduce(0) { $0 + inDisplayCurrency($1) },
                    receipts: recs.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private var chartData: [MonthSpending] {
        Array(months.sorted { $0.id < $1.id }.suffix(6))
    }

    private var monthToDateTotal: Double {
        receipts
            .filter { $0.monthKey == currentMonthKey }
            .reduce(0) { $0 + inDisplayCurrency($1) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)

                    if !chartData.isEmpty {
                        SpendingChart(data: chartData, displayCurrency: displayCurrency)
                            .frame(height: 200)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                ForEach(months) { month in
                    Section {
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
                    } header: {
                        HStack {
                            Text(month.label)
                            Spacer()
                            Text(month.total, format: .currency(code: displayCurrency))
                                .fontWeight(.semibold)
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
