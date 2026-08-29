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

    @AppStorage("preferredUnit") private var preferredUnit: WeightUnit = .kilograms

    /// The stored weight rendered in the selected unit, at the precision the form shows. Both the
    /// Details row and the change check read this so they can never disagree about the value.
    private var displayedWeight: String {
        String(format: "%.1f", preferredUnit.fromKilograms(Double(entry.weight)))
    }

    var body: some View {
        Form {
            Section("Details") {
                LabeledContent("Weight") {
                    Text("\(displayedWeight) \(preferredUnit.suffix)")
                }
                LabeledContent("Date") {
                    Text(entry.date, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                }
            }

            Section("Edit") {
                TextField("Weight (\(preferredUnit.suffix))", text: $weightInput)
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
        // Both sides are the displayed unit at one decimal. Comparing against the raw stored
        // value would report a change the user never made, and Done saves on changes, so it would
        // quietly rewrite the weight on close. Parsed, not string-compared, so "70.30" and "70.3"
        // stay equal.
        Float(weightInput) != Float(displayedWeight) || dateInput != entry.date
    }

    private func syncInputs() {
        weightInput = displayedWeight
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

        // Typed in the selected unit, stored in kilograms.
        entry.weight = Float(preferredUnit.toKilograms(Double(weightValue)))
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
