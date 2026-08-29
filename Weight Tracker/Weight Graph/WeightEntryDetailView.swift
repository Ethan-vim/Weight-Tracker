import SwiftUI
import SwiftData

struct WeightEntryDetailView: View {
    @Bindable var entry: WeightItem
    var onDismiss: () -> Void

    // Unsorted: this is only a membership test for same-day collisions.
    @Query private var weights: [WeightItem]

    @Environment(\.modelContext) private var modelContext

    @State private var weightInput: String = ""
    @State private var dateInput: Date = Date()
    @State private var warningText: String = ""

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Weight") {
                    Text(Double(entry.weight), format: .number.precision(.fractionLength(1)))
                }
                LabeledContent("Date") {
                    Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                }
            }

            Section("Edit") {
                TextField("Weight", text: $weightInput)
                    .keyboardType(.decimalPad)
                DatePicker("Date", selection: $dateInput, displayedComponents: [.date])
            }

            if !warningText.isEmpty {
                Section {
                    Text(warningText)
                        .foregroundStyle(Color.red)
                }
            }

            Section {
                Button("Save Changes") {
                    saveChanges()
                }
                .disabled(!hasChanges)

                Button("Delete Entry", role: .destructive) {
                    deleteEntry()
                }
            }

            Section {
                Button("Back to Graph") {
                    dismissSavingChanges()
                }
            }
        }
        .navigationTitle("Weight Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismissSavingChanges() }
            }
        }
        .onAppear(perform: syncInputs)
        .onChange(of: entry.persistentModelID) { _, _ in
            syncInputs()
        }
    }

    private var hasChanges: Bool {
        // weightInput is rendered at one decimal, so a stored 70.25 shows as "70.3".
        // Comparing against the raw value would report a change the user never made, and
        // Done saves on changes, so it would quietly rewrite 70.25 to 70.3 on close.
        // Parsed, not string-compared, so "70.30" and "70.3" stay equal.
        Float(weightInput) != Float(String(format: "%.1f", entry.weight)) || dateInput != entry.date
    }

    private func syncInputs() {
        weightInput = String(format: "%.1f", entry.weight)
        dateInput = entry.date
        warningText = ""
    }

    @discardableResult
    private func saveChanges() -> Bool {
        guard let weightValue = Float(weightInput) else {
            warningText = "Please input your weight in number format"
            return false
        }

        guard weightValue > 0 else {
            warningText = "Please input a weight greater than zero"
            return false
        }

        // Only a date move can collide; a weight-only edit must stay editable even for
        // entries that already share a day from before this check existed.
        if !Calendar.current.isDate(dateInput, inSameDayAs: entry.date) {
            guard !weights.contains(where: {
                $0.persistentModelID != entry.persistentModelID
                    && Calendar.current.isDate($0.date, inSameDayAs: dateInput)
            }) else {
                warningText = "That date already has a weight entry"
                return false
            }
        }

        entry.weight = weightValue
        entry.date = dateInput
        warningText = ""
        return true
    }

    private func dismissSavingChanges() {
        // Done sits in .confirmationAction, so it reads as "commit". Discarding a pending
        // date edit there is what leaves the main page still looking blocked.
        guard hasChanges else {
            onDismiss()
            return
        }
        if saveChanges() { onDismiss() }
    }

    private func deleteEntry() {
        modelContext.delete(entry)
        onDismiss()
    }
}
