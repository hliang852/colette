import SwiftUI

/// A single horizontal bar split into two segments — Groceries (blue) and
/// Dining Out (orange) — showing each category's share of this month's
/// combined spending. Used on the Groceries and Dining Out tabs so each one
/// shows how it stacks up against the other, without a per-category budget.
struct CategorySplitBar: View {
    /// This month's total for each category, in whatever currency is being
    /// displayed. Categories with 0 still render (as a hairline) so the bar
    /// never disappears just because one side hasn't spent anything yet.
    let groceryTotal: Double
    let diningTotal: Double

    private var combinedTotal: Double { groceryTotal + diningTotal }

    private var groceryShare: Double {
        guard combinedTotal > 0 else { return 0.5 }
        return groceryTotal / combinedTotal
    }

    private var diningShare: Double {
        guard combinedTotal > 0 else { return 0.5 }
        return diningTotal / combinedTotal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: combinedTotal > 0 ? 2 : 0) {
                    RoundedRectangle(cornerRadius: UIMetrics.barCornerRadius)
                        .fill(ReceiptCategory.grocery.color)
                        .frame(width: max(geo.size.width * groceryShare, combinedTotal > 0 ? 4 : geo.size.width / 2))
                    RoundedRectangle(cornerRadius: UIMetrics.barCornerRadius)
                        .fill(ReceiptCategory.diningOut.color)
                        .frame(width: max(geo.size.width * diningShare, combinedTotal > 0 ? 4 : geo.size.width / 2))
                }
            }
            .frame(height: 14)

            HStack {
                Label("\(Int((groceryShare * 100).rounded()))% Groceries", systemImage: "cart.fill")
                    .foregroundStyle(ReceiptCategory.grocery.color)
                Spacer()
                Label("\(Int((diningShare * 100).rounded()))% Dining Out", systemImage: "fork.knife")
                    .foregroundStyle(ReceiptCategory.diningOut.color)
            }
            .font(.caption)
            .fontWeight(.medium)
        }
    }
}
