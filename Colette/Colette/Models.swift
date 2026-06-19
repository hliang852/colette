import Foundation
import SwiftData

@Model
final class Receipt {
    var date: Date
    var storeName: String
    var total: Double
    var currency: String = "USD"        // the currency this receipt was paid in
    @Relationship(deleteRule: .cascade, inverse: \LineItem.receipt)
    var items: [LineItem]

    init(date: Date = .now, storeName: String = "", total: Double = 0,
         currency: String = "USD", items: [LineItem] = []) {
        self.date = date
        self.storeName = storeName
        self.total = total
        self.currency = currency
        self.items = items
    }

    /// Sortable month bucket, e.g. "2026-06". Used to group spending by month.
    var monthKey: String {
        DateHelpers.monthKey.string(from: date)
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
