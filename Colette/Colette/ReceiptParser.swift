import Foundation
@preconcurrency import Vision
import UIKit

struct ParsedReceipt {
    var storeName: String
    var date: Date
    var total: Double
}

enum ReceiptParser {

    // MARK: - OCR

    /// Runs Apple's on-device Vision text recognition and returns the lines
    /// roughly in top-to-bottom reading order.
    static func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.normalizedUp().cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                let sorted = observations.sorted { $0.boundingBox.maxY > $1.boundingBox.maxY }
                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    // MARK: - Parsing (total only)

    static func parse(lines: [String]) -> ParsedReceipt {
        let store = lines.first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            ?? "Unknown store"
        return ParsedReceipt(
            storeName: store,
            date: detectDate(in: lines) ?? .now,
            total: detectTotal(in: lines)
        )
    }

    /// Matches money amounts after commas are stripped, e.g. "12.99", "1234.56".
    private static let amountRegex = try! NSRegularExpression(pattern: #"\d+\.\d{2}"#)

    /// Returns every money amount found on a line (treats "," as thousands separator).
    private static func amounts(in line: String) -> [Double] {
        let cleaned = line.replacingOccurrences(of: ",", with: "")
        let ns = cleaned as NSString
        let matches = amountRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { Double(ns.substring(with: $0.range)) }
    }

    private static func detectTotal(in lines: [String]) -> Double {
        // The amount usually sits on the labeled line; if not, it's often the line below.
        func amountNear(_ index: Int) -> Double? {
            if let here = amounts(in: lines[index]).max() { return here }
            if index + 1 < lines.count, let below = amounts(in: lines[index + 1]).max() { return below }
            return nil
        }

        // 1) Strongest signal: a line explicitly labeled "TOTAL PURCHASE".
        for (i, line) in lines.enumerated() where line.uppercased().contains("TOTAL PURCHASE") {
            if let amount = amountNear(i) { return amount }
        }

        // 2) A line labeled "TOTAL" (but never SUBTOTAL).
        var totalCandidates: [Double] = []
        for (i, line) in lines.enumerated() {
            let upper = line.uppercased()
            if upper.contains("SUBTOTAL") || upper.contains("SUB TOTAL") { continue }
            if upper.contains("TOTAL"), let amount = amountNear(i) {
                totalCandidates.append(amount)
            }
        }
        if let best = totalCandidates.max() { return best }

        // 3) Other total-like labels.
        let otherKeywords = ["BALANCE DUE", "AMOUNT DUE", "BALANCE"]
        var otherCandidates: [Double] = []
        for (i, line) in lines.enumerated()
        where otherKeywords.contains(where: { line.uppercased().contains($0) }) {
            if let amount = amountNear(i) { otherCandidates.append(amount) }
        }
        if let best = otherCandidates.max() { return best }

        // 4) Fallback: the largest amount anywhere is usually the total.
        return lines.flatMap { amounts(in: $0) }.max() ?? 0
    }

    // MARK: - Date

    private static let dateTokenRegex = try! NSRegularExpression(
        pattern: #"\d{1,4}[/\-.]\d{1,2}[/\-.]\d{1,4}"#)
    private static let dateFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "MM/dd/yy",
                                      "M/d/yyyy", "M/d/yy", "MM-dd-yyyy", "MM-dd-yy",
                                      "M-d-yy", "dd/MM/yyyy", "dd.MM.yyyy"]

    private static func detectDate(in lines: [String]) -> Date? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let upperBound = calendar.date(byAdding: .day, value: 2, to: .now) ?? .now

        for line in lines {
            let ns = line as NSString
            guard let match = dateTokenRegex.firstMatch(
                in: line, range: NSRange(location: 0, length: ns.length)) else { continue }
            let token = ns.substring(with: match.range)

            for format in dateFormats {
                let f = DateFormatter()
                f.locale = Locale(identifier: "en_US_POSIX")
                f.dateFormat = format
                guard let date = f.date(from: token) else { continue }

                // Reject implausible dates (OCR slips / 2-digit-year misreads).
                let year = calendar.component(.year, from: date)
                if year >= currentYear - 5, year <= currentYear + 1, date <= upperBound {
                    return date
                }
            }
        }
        return nil   // caller falls back to today's date
    }
}

private extension UIImage {
    /// Returns a copy drawn upright so Vision OCR reads it correctly regardless
    /// of how the photo was captured (camera photos are often sideways).
    func normalizedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
