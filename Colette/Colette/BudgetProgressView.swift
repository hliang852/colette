import SwiftUI

/// A progress bar plus a "x% of budget spent" (or "Over budget") label, and
/// the goal amount. Shared by the Home tab's overall goal and the per-category
/// budgets on the Groceries / Dining Out tabs.
struct BudgetProgressView: View {
    /// Fraction of the budget spent so far, e.g. 0.42 for 42%.
    let progress: Double
    /// The budget amount, already converted into `currencyCode`.
    let goalAmount: Double
    let currencyCode: String

    private var isOverBudget: Bool { progress > 1.0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: min(progress, 1.0))
                .tint(isOverBudget ? .red : .accentColor)

            HStack {
                Text(isOverBudget ? "Over budget" : "\(Int((progress * 100).rounded()))% of budget spent")
                    .font(.caption)
                    .foregroundStyle(isOverBudget ? .red : .secondary)
                Spacer()
                Text("Budget: \(goalAmount, format: .currency(code: currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
