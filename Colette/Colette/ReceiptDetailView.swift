import SwiftUI
import SwiftData

/// View and edit a saved receipt. Edits bind directly to the model and persist
/// automatically.
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    // Text mirror of receipt.total so the field can be blank (rather than a
    // persistent "0") when the amount is zero, and only writes back to the
    // model as the user types.
    @State private var totalText = ""

    var body: some View {
        Form {
            Section("Receipt") {
                TextField("Store", text: $receipt.storeName)
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
                HStack {
                    Text("Total")
                    Spacer()
                    TextField("0.00", text: $totalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: totalText) { _, newValue in
                            receipt.total = Double(newValue) ?? 0
                        }
                }
                Picker("Currency", selection: $receipt.currency) {
                    ForEach(CurrencyConverter.supported, id: \.self) { Text($0).tag($0) }
                }
                Picker("Category", selection: $receipt.category) {
                    ForEach(ReceiptCategory.allCases) { Text($0.rawValue).tag($0) }
                }
            }

            Section {
                Button(role: .destructive) {
                    context.delete(receipt)
                    dismiss()
                } label: {
                    Label("Delete Receipt", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(receipt.storeName.isEmpty ? "Receipt" : receipt.storeName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            totalText = receipt.total == 0 ? "" : String(format: "%.2f", receipt.total)
        }
    }
}
