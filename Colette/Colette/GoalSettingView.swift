import SwiftUI

/// Lets the user set (or remove) a recurring monthly spending goal, entered in
/// either USD or HKD. Shows a live converted preview in the other currency
/// using the same hardcoded 1 USD = 7.8 HKD rate as the rest of the app.
struct GoalSettingView: View {
    /// Stored goal amount, in `goalCurrency`. 0 means "no goal set".
    @Binding var goalAmount: Double
    /// Which currency the stored goal amount is denominated in.
    @Binding var goalCurrency: String

    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String
    @State private var currency: String

    init(goalAmount: Binding<Double>, goalCurrency: Binding<String>) {
        self._goalAmount = goalAmount
        self._goalCurrency = goalCurrency
        _amountText = State(initialValue: goalAmount.wrappedValue > 0
            ? String(format: "%.2f", goalAmount.wrappedValue) : "")
        _currency = State(initialValue: goalCurrency.wrappedValue)
    }

    private var enteredAmount: Double { Double(amountText) ?? 0 }

    private var otherCurrency: String {
        currency == "USD" ? "HKD" : "USD"
    }

    /// The entered amount converted into the other supported currency, so the
    /// user can see both sides of the goal at once.
    private var convertedAmount: Double {
        CurrencyConverter.convert(enteredAmount, from: currency, to: otherCurrency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Amount")
                        Spacer()
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Currency", selection: $currency) {
                        ForEach(CurrencyConverter.supported, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("Monthly spending goal")
                } footer: {
                    if enteredAmount > 0 {
                        Text("≈ \(convertedAmount, format: .currency(code: otherCurrency)) at the fixed 1 USD = 7.8 HKD rate")
                    } else {
                        Text("This goal applies to every calendar month. Leave it at 0 to go without one.")
                    }
                }

                if goalAmount > 0 {
                    Section {
                        Button(role: .destructive) {
                            goalAmount = 0
                            amountText = ""
                            dismiss()
                        } label: {
                            Label("Remove Goal", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Spending Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        goalAmount = enteredAmount
                        goalCurrency = currency
                        dismiss()
                    }
                }
            }
        }
    }
}
