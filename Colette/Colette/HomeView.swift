import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Home tab: a combined overview of grocery + dining-out spending, with
/// a stacked monthly/daily chart, a monthly spending goal, and a list of the
/// most recent receipts.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Receipt.date, order: .reverse) private var receipts: [Receipt]

    /// Mirrors the existing USD/HKD picker on the per-category tabs.
    @State private var displayCurrency = "USD"
    @State private var granularity: SpendingGranularity = .monthly

    // MARK: - Goal state

    /// The recurring monthly spending goal, persisted across launches. Stored
    /// in whichever currency it was entered in (`goalCurrency`); 0 means no
    /// goal has been set.
    @AppStorage("monthlyGoalAmount") private var goalAmount: Double = 0
    @AppStorage("monthlyGoalCurrency") private var goalCurrency: String = "USD"
    @State private var showGoalSheet = false

    // MARK: - Backup / restore state

    @State private var shareURL: URL?
    @State private var showBackupSaved = false
    @State private var exportErrorMessage: String?

    @State private var isImporterPresented = false
    @State private var pendingImport: PendingImport?
    @State private var importErrorMessage: String?
    @State private var showImportSuccess = false
    @State private var importedCount = 0

    /// Backs the confirmation alert shown after a backup file is parsed but
    /// before anything is actually written.
    private struct PendingImport: Identifiable {
        let id = UUID()
        let backup: BackupFile
        let message: String
    }

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

    /// The goal converted into whatever currency is currently being displayed,
    /// regardless of which currency it was originally entered in. 0 if unset.
    private var goalInDisplayCurrency: Double {
        guard goalAmount > 0 else { return 0 }
        return CurrencyConverter.convert(goalAmount, from: goalCurrency, to: displayCurrency)
    }

    /// Fraction of the goal spent so far this month, e.g. 0.42 for 42%.
    /// nil when there's no goal set, so the progress bar can hide itself.
    private var goalProgress: Double? {
        guard goalInDisplayCurrency > 0 else { return nil }
        return monthToDateTotal / goalInDisplayCurrency
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

                    // Sits below the total and above the trend chart, per the
                    // home tab's reading order: how much, against goal, then trend.
                    if let goalProgress {
                        goalProgressView(progress: goalProgress)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                    }

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showGoalSheet = true
                    } label: {
                        Label("Goal", systemImage: "target")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportData()
                        } label: {
                            Label("Export Data", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            isImporterPresented = true
                        } label: {
                            Label("Import Data", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showGoalSheet) {
                GoalSettingView(goalAmount: $goalAmount, goalCurrency: $goalCurrency)
            }
        }
        // Export: native share sheet over the freshly written JSON file.
        .sheet(item: $shareURL) { url in
            ShareSheet(items: [url]) { completed in
                if completed { showBackupSaved = true }
            }
        }
        .alert("Backup Saved", isPresented: $showBackupSaved) {
            Button("OK", role: .cancel) {}
        }
        .alert("Couldn't Export", isPresented: errorBinding($exportErrorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "")
        }
        // Import: file picker -> parse -> confirm (with replace warning) -> apply.
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                handlePickedFile(url)
            case .failure:
                importErrorMessage = BackupError.unreadable.errorDescription
            }
        }
        .alert(
            "Import Backup",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            presenting: pendingImport
        ) { item in
            Button("Cancel", role: .cancel) {}
            Button("Import", role: .destructive) {
                BackupManager.apply(item.backup, replacing: receipts, in: context)
                importedCount = item.backup.receipts.count
                showImportSuccess = true
            }
        } message: { item in
            Text(item.message)
        }
        .alert("Import Complete", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(importedCount) receipt\(importedCount == 1 ? "" : "s") imported.")
        }
        .alert("Couldn't Import", isPresented: errorBinding($importErrorMessage)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    // MARK: - Backup / restore actions

    private func exportData() {
        do {
            shareURL = try BackupManager.exportFile(from: receipts)
        } catch {
            exportErrorMessage = "Couldn't create the backup file. Please try again."
        }
    }

    private func handlePickedFile(_ url: URL) {
        do {
            let backup = try BackupManager.parseBackup(from: url)
            let count = backup.receipts.count
            var message = "Found \(count) receipt\(count == 1 ? "" : "s")\(dateRangeText(for: backup.receipts))."
            if !receipts.isEmpty {
                message += " This will replace your current \(receipts.count) receipt\(receipts.count == 1 ? "" : "s")."
            }
            pendingImport = PendingImport(backup: backup, message: message)
        } catch {
            importErrorMessage = (error as? BackupError)?.errorDescription
                ?? BackupError.unreadable.errorDescription
        }
    }

    /// e.g. " from Jan 2026–Jun 2026", or "" if the backup has no receipts.
    private func dateRangeText(for backups: [ReceiptBackup]) -> String {
        guard let minDate = backups.map(\.date).min(),
              let maxDate = backups.map(\.date).max() else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let start = formatter.string(from: minDate)
        let end = formatter.string(from: maxDate)
        return start == end ? " from \(start)" : " from \(start)–\(end)"
    }

    /// Adapts an `Optional<String>` error-message binding into the Bool
    /// binding `.alert(isPresented:)` expects.
    private func errorBinding(_ message: Binding<String?>) -> Binding<Bool> {
        Binding(get: { message.wrappedValue != nil }, set: { if !$0 { message.wrappedValue = nil } })
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

    /// Progress toward this month's goal. Turns red and shows "Over goal"
    /// once spending passes 100%, instead of just clipping the bar at full.
    private func goalProgressView(progress: Double) -> some View {
        let isOverBudget = progress > 1.0

        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: min(progress, 1.0))
                .tint(isOverBudget ? .red : .accentColor)

            HStack {
                Text(isOverBudget ? "Over goal" : "\(Int((progress * 100).rounded()))% of goal")
                    .font(.caption)
                    .foregroundStyle(isOverBudget ? .red : .secondary)
                Spacer()
                Text("Goal: \(goalInDisplayCurrency, format: .currency(code: displayCurrency))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
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

/// Lets `.sheet(item:)` take a plain `URL` directly.
extension URL: Identifiable {
    public var id: String { absoluteString }
}
