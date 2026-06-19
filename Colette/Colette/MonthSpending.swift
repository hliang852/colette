import Foundation

/// One month's worth of spending, used by both the summary list and the chart.
struct MonthSpending: Identifiable {
    let id: String          // month key, e.g. "2026-06"
    let label: String       // "June 2026"
    let date: Date          // first day of the month (for the chart's time axis)
    let total: Double
    let receipts: [Receipt]
}
