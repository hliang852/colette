import SwiftUI
import SwiftData

/// Shown right after a scan: runs OCR for the total, presents it, and lets the
/// user confirm or fix it before saving.
struct ReviewView: View {
    let image: UIImage

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing = true
    @State private var storeName = ""
    @State private var date = Date.now
    @State private var total = 0.0
    @State private var currency = "USD"
    @State private var saveToPhotos = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt") {
                    TextField("Store", text: $storeName)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    HStack {
                        Text("Total")
                        Spacer()
                        TextField("0.00", value: $total, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyConverter.supported, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section {
                    Toggle("Save photo to Photos", isOn: $saveToPhotos)
                } footer: {
                    Text("Keeps a copy of the receipt image in your iPhone's photo library.")
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(isProcessing)
                }
            }
            .overlay {
                if isProcessing {
                    ProgressView("Reading total…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .task { await process() }
        }
    }

    private func process() async {
        let lines = await ReceiptParser.recognizeText(in: image)
        let parsed = ReceiptParser.parse(lines: lines)
        storeName = parsed.storeName
        date = parsed.date
        total = parsed.total
        isProcessing = false
    }

    private func save() {
        let receipt = Receipt(date: date, storeName: storeName, total: total, currency: currency)
        context.insert(receipt)

        if saveToPhotos {
            PhotoSaver.saveToPhotoAlbum(image)
        }
        dismiss()
    }
}
