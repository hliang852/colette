import SwiftUI
import SwiftData

/// Shown after a scan, or for manual entry when there's no image: runs OCR
/// for the total when a scanned image is provided, presents it, and lets the
/// user confirm or fix it before saving — including which category it belongs
/// to (Groceries or Dining Out), picked the same way as currency.
struct ReviewView: View {
    /// nil when the user chose "Enter Manually" instead of scanning.
    let image: UIImage?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isProcessing: Bool
    @State private var storeName = ""
    @State private var date = Date.now
    @State private var total = 0.0
    @State private var currency = "USD"
    @State private var category: ReceiptCategory = .grocery
    @State private var saveToPhotos = false

    init(image: UIImage?) {
        self.image = image
        // Nothing to OCR for manual entry, so skip the processing state.
        _isProcessing = State(initialValue: image != nil)
    }

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
                    Picker("Category", selection: $category) {
                        ForEach(ReceiptCategory.allCases) { Text($0.rawValue).tag($0) }
                    }
                }

                // Only relevant when there's an actual photo to keep.
                if image != nil {
                    Section {
                        Toggle("Save photo to Photos", isOn: $saveToPhotos)
                    } footer: {
                        Text("Keeps a copy of the receipt image in your iPhone's photo library.")
                    }
                }
            }
            .navigationTitle(image == nil ? "New Receipt" : "Review")
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
        guard let image else { return }   // manual entry: nothing to OCR
        let lines = await ReceiptParser.recognizeText(in: image)
        let parsed = ReceiptParser.parse(lines: lines)
        storeName = parsed.storeName
        date = parsed.date
        total = parsed.total
        isProcessing = false
    }

    private func save() {
        let receipt = Receipt(date: date, storeName: storeName, total: total,
                               currency: currency, category: category)
        context.insert(receipt)

        if let image, saveToPhotos {
            PhotoSaver.saveToPhotoAlbum(image)
        }
        dismiss()
    }
}
