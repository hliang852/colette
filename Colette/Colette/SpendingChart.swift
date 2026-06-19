import SwiftUI
import Charts

/// A bar chart of spending per month, newest months on the right.
/// Amounts are already converted to `displayCurrency` by the caller.
struct SpendingChart: View {
    let data: [MonthSpending]
    let displayCurrency: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monthly spending")
                .font(.headline)

            Chart(data) { month in
                BarMark(
                    x: .value("Month", month.date, unit: .month),
                    y: .value("Spent", month.total)
                )
                .foregroundStyle(Color.accentColor.gradient)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated))
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
