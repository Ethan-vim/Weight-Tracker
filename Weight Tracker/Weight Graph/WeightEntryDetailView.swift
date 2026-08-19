import SwiftUI
import SwiftData

struct WeightEntryDetailView: View {
    @Bindable var entry: WeightItem
    var onDismiss: () -> Void

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
                    onDismiss()
                }
            }
        }
        .navigationTitle("Weight Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDismiss() }
            }
        }
        .onAppear(perform: syncInputs)
        .onChange(of: entry.persistentModelID) { _, _ in
            syncInputs()
        }
    }

    private var hasChanges: Bool {
        Float(weightInput) != entry.weight || dateInput != entry.date
    }

    private func syncInputs() {
        weightInput = String(format: "%.1f", entry.weight)
        dateInput = entry.date
        warningText = ""
    }

    private func saveChanges() {
        guard let weightValue = Float(weightInput), weightValue > 0 else {
            warningText = "Please input your weight in number format"
            return
        }

        entry.weight = weightValue
        entry.date = dateInput
        warningText = ""
    }

    private func deleteEntry() {
        modelContext.delete(entry)
        onDismiss()
    }
}
