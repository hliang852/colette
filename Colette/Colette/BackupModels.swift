import Foundation

/// Plain, Codable mirror of `LineItem` — `@Model` classes aren't directly
/// Codable, so backups go through these DTOs instead.
struct LineItemBackup: Codable {
    var name: String
    var price: Double
}

/// Plain, Codable mirror of `Receipt`.
struct ReceiptBackup: Codable {
    var date: Date
    var storeName: String
    var total: Double
    var currency: String
    var category: ReceiptCategory
    var items: [LineItemBackup]
}

/// The full contents of one exported backup file.
struct BackupFile: Codable {
    var version: Int
    var exportDate: Date
    var receipts: [ReceiptBackup]
}
