import SwiftUI
import SwiftData

/// Identifiable wrapper so a scanned image can drive a `.sheet(item:)`.
struct ScannedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    @State private var showScanner = false
    @State private var pendingScan: ScannedImage?
    @State private var didAutoLaunch = false

    /// Which currency the whole summary is displayed in. Each receipt's amount
    /// is converted from its own currency into this one.
    @State private var displayCurrency = "USD"

    /// Converts a receipt's stored total into the chosen display currency.
    private func inDisplayCurrency(_ receipt: Receipt) -> Double {
        CurrencyConverter.convert(receipt.total, from: receipt.currency, to: displayCurrency)
    }

    /// All months, newest first — drives the receipt list. Totals are in displayCurrency.
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

    /// Up to the last 6 months, oldest first — drives the chart.
    private var chartData: [MonthSpending] {
        Array(months.sorted { $0.id < $1.id }.suffix(6))
    }

    /// Grand total spent this calendar month so far, in displayCurrency.
    private var monthToDateTotal: Double {
        receipts
            .filter { $0.monthKey == currentMonthKey }
            .reduce(0) { $0 + inDisplayCurrency($1) }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary header + chart at the top.
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

                // Per-month receipt lists.
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
            .navigationTitle("Groceries")
            .overlay {
                if receipts.isEmpty {
                    ContentUnavailableView(
                        "No receipts yet",
                        systemImage: "doc.text.viewfinder",
                        description: Text("Tap the camera to scan your first receipt.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan", systemImage: "camera")
                    }
                }
            }
        }
        // Document scanner: auto-detects the receipt's edges, straightens, and
        // crops it for clean OCR. Its Cancel button returns to this summary.
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner(
                onComplete: { image in
                    showScanner = false
                    pendingScan = ScannedImage(image: image)
                },
                onCancel: { showScanner = false }
            )
            .ignoresSafeArea()
        }
        // The review screen, shown once a scan completes.
        .sheet(item: $pendingScan) { scan in
            ReviewView(image: scan.image)
        }
        // Open the scanner on launch. Remove this block to land on the summary
        // first instead.
        .onAppear {
            if !didAutoLaunch {
                didAutoLaunch = true
                showScanner = true
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
