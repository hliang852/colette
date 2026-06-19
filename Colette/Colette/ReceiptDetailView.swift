import SwiftUI
import SwiftData

/// View and edit a saved receipt. Edits bind directly to the model and persist
/// automatically.
struct ReceiptDetailView: View {
    @Bindable var receipt: Receipt
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Receipt") {
                TextField("Store", text: $receipt.storeName)
                DatePicker("Date", selection: $receipt.date, displayedComponents: .date)
                HStack {
                    Text("Total")
                    Spacer()
                    TextField("0.00", value: $receipt.total, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Currency", selection: $receipt.currency) {
                    ForEach(CurrencyConverter.supported, id: \.self) { Text($0).tag($0) }
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
    }
}
