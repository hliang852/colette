import Foundation

/// A collapsible group of receipts for one month (used for months other than
/// the current one).
struct MonthGroup: Identifiable {
    let id: String        // month key, e.g. "2026-05"
    let label: String     // "May 2026"
    let receipts: [Receipt]
}

/// A collapsible group of months for one year (used for years other than
/// the current one).
struct YearGroup: Identifiable {
    let id: String         // year key, e.g. "2025"
    let label: String      // "2025"
    let months: [MonthGroup]
}

/// Splits `receipts` (any order) into three buckets for display:
/// - `currentMonth`: receipts from the current calendar month, shown flat.
/// - `otherMonthsThisYear`: receipts from earlier months in the current year,
///   grouped into one collapsible section per month.
/// - `otherYears`: receipts from prior years, grouped into one collapsible
///   section per year, each containing its own collapsible months.
///
/// All groups are newest-first.
func groupReceiptsForDisplay(_ receipts: [Receipt]) -> (
    currentMonth: [Receipt],
    otherMonthsThisYear: [MonthGroup],
    otherYears: [YearGroup]
) {
    let thisMonth = currentMonthKey
    let thisYear = currentYearKey

    let current = receipts
        .filter { $0.monthKey == thisMonth }
        .sorted { $0.date > $1.date }

    let otherThisYear = receipts.filter { $0.monthKey != thisMonth && $0.yearKey == thisYear }
    let otherMonthGroups = Dictionary(grouping: otherThisYear, by: \.monthKey)
        .map { key, recs in
            MonthGroup(id: key, label: monthLabel(from: key), receipts: recs.sorted { $0.date > $1.date })
        }
        .sorted { $0.id > $1.id }

    let priorYears = receipts.filter { $0.yearKey != thisYear }
    let yearGroups = Dictionary(grouping: priorYears, by: \.yearKey)
        .map { year, recs -> YearGroup in
            let months = Dictionary(grouping: recs, by: \.monthKey)
                .map { key, recs in
                    MonthGroup(id: key, label: monthLabel(from: key), receipts: recs.sorted { $0.date > $1.date })
                }
                .sorted { $0.id > $1.id }
            return YearGroup(id: year, label: year, months: months)
        }
        .sorted { $0.id > $1.id }

    return (current, otherMonthGroups, yearGroups)
}
