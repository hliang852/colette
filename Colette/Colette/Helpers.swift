import Foundation

/// The device's currency code (falls back to USD), used for formatting amounts.
var currencyCode: String { Locale.current.currency?.identifier ?? "USD" }

/// Shared, reused date formatters. Building a DateFormatter is expensive, so we
/// create each one once instead of on every call / every screen redraw.
enum DateHelpers {
    static let monthKey: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f
    }()

    static let monthLabel: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

/// The month key for the current calendar month, e.g. "2026-06".
var currentMonthKey: String { DateHelpers.monthKey.string(from: .now) }

/// Turns a "2026-06" month key into a friendly label like "June 2026".
func monthLabel(from key: String) -> String {
    guard let date = DateHelpers.monthKey.date(from: key) else { return key }
    return DateHelpers.monthLabel.string(from: date)
}

/// First day of the month for a "2026-06" key (used as the chart's x value).
func firstOfMonth(from key: String) -> Date {
    DateHelpers.monthKey.date(from: key) ?? .now
}
