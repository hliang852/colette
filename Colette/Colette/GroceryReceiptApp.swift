import SwiftUI
import SwiftData

@main
struct GroceryReceiptApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Sets up the local database for receipts + their line items.
        .modelContainer(for: [Receipt.self, LineItem.self])
    }
}
