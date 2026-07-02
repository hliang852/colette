import SwiftUI
import Charts

/// A bar chart of daily spending for a single category (Groceries or Dining
/// Out), most recent days on the right. Amounts are already converted to
/// `displayCurrency` by the caller. Bars are drawn in `barColor` so the
/// Groceries tab reads blue and the Dining Out tab reads orange.
struct SpendingChart: View {
    let data: [PeriodSpending]
    let displayCurrency: String
    let barColor: Color

    /// Thins the x-axis labels so up to ~14 days of bars don't crowd the axis.
    private var xAxisDates: [Date] {
        let maxLabels = 7
        guard data.count > maxLabels else { return data.map(\.date) }
        let step = Int(ceil(Double(data.count) / Double(maxLabels)))
        return data.enumerated().compactMap { index, period in
            index % step == 0 ? period.date : nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily spending")
                .font(.headline)

            Chart(data) { period in
                BarMark(
                    x: .value("Day", period.date, unit: .day),
                    y: .value("Spent", period.total)
                )
                .foregroundStyle(barColor.gradient)
                .cornerRadius(UIMetrics.barCornerRadius)
            }
            .chartXAxis {
                AxisMarks(values: xAxisDates) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
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
}
