import Foundation

/// Converts between USD and HKD at a fixed, hardcoded rate of 1 USD = 7.8 HKD.
enum CurrencyConverter {
    static let hkdPerUSD = 7.8
    static let supported = ["USD", "HKD"]

    /// Converts `amount` from one currency to another (USD/HKD only).
    static func convert(_ amount: Double, from: String, to: String) -> Double {
        guard from != to else { return amount }
        let amountInUSD = (from == "HKD") ? amount / hkdPerUSD : amount
        return (to == "HKD") ? amountInUSD * hkdPerUSD : amountInUSD
    }
}
