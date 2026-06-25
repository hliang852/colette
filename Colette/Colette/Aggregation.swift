import Foundation

/// Whether the Home chart buckets receipts by month or by day.
enum SpendingGranularity {
    case monthly
    case daily
}

/// One time bucket's spending broken down by category, used by the Home tab's
/// stacked chart. Unlike `MonthSpending` (always monthly, single-category list),
/// this supports both granularities and carries a per-category split.
struct PeriodSpending: Identifiable {
    let id: String           // month key ("2026-06") or day key ("2026-06-19")
    let label: String
    let date: Date
    let totals: [ReceiptCategory: Double]

    var total: Double { totals.values.reduce(0, +) }
}

/// Groups receipts into monthly or daily buckets, summing each receipt's
/// already-converted amount per category. Returned oldest-first.
func aggregateSpending(
    _ receipts: [Receipt],
    by granularity: SpendingGranularity,
    convert: (Receipt) -> Double
) -> [PeriodSpending] {
    let keyOf: (Receipt) -> String = (granularity == .monthly) ? { $0.monthKey } : { $0.dayKey }

    let grouped = Dictionary(grouping: receipts, by: keyOf)
    let periods = grouped.map { key, recs -> PeriodSpending in
        var totals: [ReceiptCategory: Double] = [:]
        for receipt in recs {
            totals[receipt.category, default: 0] += convert(receipt)
        }

        let date: Date
        let label: String
        if granularity == .monthly {
            date = firstOfMonth(from: key)
            label = monthLabel(from: key)
        } else {
            date = DateHelpers.dayKey.date(from: key) ?? .now
            label = dayLabel(from: key)
        }

        return PeriodSpending(id: key, label: label, date: date, totals: totals)
    }
    return periods.sorted { $0.id < $1.id }
}
