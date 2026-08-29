import SwiftUI

struct SettingsPage: View {
    @Binding var selectedPage: Page

    @AppStorage("preferredUnit") private var preferredUnit: WeightUnit = .kilograms
    @AppStorage("weightGoal") private var weightGoal: String = ""

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    selectedPage = .main
                } label: {
                    Text("Back")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 28)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Form {
                Section {
                    Picker("Unit", selection: $preferredUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.pickerLabel).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preferred Unit")
                        Text("Changes how weights are shown. Entries themselves are unchanged.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    TextField("e.g. gain weight for muscle", text: $weightGoal, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight Goal")
                        Text("Sent with your meal photos so the calorie estimator's advice follows your goal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsPage(selectedPage: .constant(.settings))
}
