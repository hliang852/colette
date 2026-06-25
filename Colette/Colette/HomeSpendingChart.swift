import SwiftUI
import Charts

/// A stacked bar chart of grocery + dining-out spending, switchable between
/// monthly and daily granularity. Amounts are already converted to
/// `displayCurrency` by the caller. Used only on the Home tab — the
/// single-category tabs keep using the original `SpendingChart`.
struct HomeSpendingChart: View {
    let data: [PeriodSpending]
    let displayCurrency: String
    let granularity: SpendingGranularity

    private var unit: Calendar.Component { granularity == .monthly ? .month : .day }

    /// Which dates get an axis label. Monthly view has at most 6 bars, so every
    /// one gets a tick. Daily view can have up to 14 — labeling all of them
    /// crowds and overlaps, so we thin down to roughly 7 evenly spaced labels.
    private var xAxisDates: [Date] {
        guard granularity == .daily else { return data.map(\.date) }
        let maxLabels = 7
        guard data.count > maxLabels else { return data.map(\.date) }
        let step = Int(ceil(Double(data.count) / Double(maxLabels)))
        return data.enumerated().compactMap { index, period in
            index % step == 0 ? period.date : nil
        }
    }

    var body: some View {
        Chart(data) { period in
            ForEach(ReceiptCategory.allCases) { category in
                BarMark(
                    x: .value("Period", period.date, unit: unit),
                    y: .value("Spent", period.totals[category] ?? 0)
                )
                .foregroundStyle(by: .value("Category", category.rawValue))
                .cornerRadius(4)
            }
        }
        .chartForegroundStyleScale([
            ReceiptCategory.grocery.rawValue: Color.blue,
            ReceiptCategory.diningOut.rawValue: Color.orange
        ])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            // Pinned + thinned tick values (see `xAxisDates`) instead of a
            // forced stride across every month/day — that was the source of
            // the overlapping date labels.
            AxisMarks(values: xAxisDates) { _ in
                AxisGridLine()
                if granularity == .monthly {
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
                } else {
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(amount, format: .currency(code: displayCurrency).precision(.fractionLength(0)))
                    }
                }
            }
        }
    }
}
