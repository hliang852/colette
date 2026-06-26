import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "This file couldn't be read as a Colette backup."
    }
}

enum BackupManager {
    static let currentVersion = 1

    // MARK: - Export

    /// Builds the Codable backup from the app's current receipts.
    static func makeBackup(from receipts: [Receipt]) -> BackupFile {
        let receiptBackups = receipts.map { receipt in
            ReceiptBackup(
                date: receipt.date,
                storeName: receipt.storeName,
                total: receipt.total,
                currency: receipt.currency,
                category: receipt.category,
                items: receipt.items.map { LineItemBackup(name: $0.name, price: $0.price) }
            )
        }
        return BackupFile(version: currentVersion, exportDate: .now, receipts: receiptBackups)
    }

    /// Encodes the backup to JSON and writes it to a dated temp file, ready
    /// to hand to the share sheet.
    static func exportFile(from receipts: [Receipt]) throws -> URL {
        let backup = makeBackup(from: receipts)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)

        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd"
        let filename = "colette-backup-\(stamp.string(from: .now)).json"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Import

    /// Reads and decodes a backup file picked via the file importer.
    static func parseBackup(from url: URL) throws -> BackupFile {
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            throw BackupError.unreadable
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let backup = try? decoder.decode(BackupFile.self, from: data) else {
            throw BackupError.unreadable
        }
        return backup
    }

    /// Deletes every existing receipt, then inserts the ones from `backup`.
    /// Always a full replace — there's no merge path.
    static func apply(_ backup: BackupFile, replacing existing: [Receipt], in context: ModelContext) {
        for receipt in existing {
            context.delete(receipt)
        }
        for receiptBackup in backup.receipts {
            let items = receiptBackup.items.map { LineItem(name: $0.name, price: $0.price) }
            let receipt = Receipt(
                date: receiptBackup.date,
                storeName: receiptBackup.storeName,
                total: receiptBackup.total,
                currency: receiptBackup.currency,
                category: receiptBackup.category,
                items: items
            )
            context.insert(receipt)
        }
    }
}
