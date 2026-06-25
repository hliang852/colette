import Foundation
import SwiftData

/// Which kind of spending a receipt represents. Drives the Groceries / Dining
/// Out tabs and the category breakdown shown on the Home tab.
enum ReceiptCategory: String, Codable, CaseIterable, Identifiable {
    case grocery = "Groceries"
    case diningOut = "Dining Out"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grocery: return "cart"
        case .diningOut: return "fork.knife"
        }
    }
}

@Model
final class Receipt {
    var date: Date
    var storeName: String
    var total: Double
    var currency: String = "USD"        // the currency this receipt was paid in
    var category: ReceiptCategory = ReceiptCategory.grocery
    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem]

    init(date: Date = .now, storeName: String = "", total: Double = 0,
         currency: String = "USD", category: ReceiptCategory = .grocery,
         items: [LineItem] = []) {
        self.date = date
        self.storeName = storeName
        self.total = total
        self.currency = currency
        self.category = category
        self.items = items
    }

    /// Sortable month bucket, e.g. "2026-06". Used to group spending by month.
    var monthKey: String {
        DateHelpers.monthKey.string(from: date)
    }

    /// Sortable day bucket, e.g. "2026-06-19". Used for the daily chart view.
    var dayKey: String {
        DateHelpers.dayKey.string(from: date)
    }
}

@Model
final class LineItem {
    var name: String
    var price: Double
    var receipt: Receipt?

    init(name: String, price: Double) {
        self.name = name
        self.price = price
    }
}
