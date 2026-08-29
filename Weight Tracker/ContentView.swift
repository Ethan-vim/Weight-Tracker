import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \WeightItem.date, order: .forward) var weights: [WeightItem]
    @Binding var selectedPage: Page
    @State private var weightInput: String = ""
    @State private var warningText: String = ""
    @State private var warningCount: Int = 0
    @State private var selectedEntry: WeightItem?

    private var isShowingDetail: Binding<Bool> {
        Binding(
            get: { selectedEntry != nil },
            set: { if !$0 { selectedEntry = nil } }
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                WeightGraphView(weights: weights, selectedEntry: $selectedEntry)
                    .frame(height: 260)

                Text(warningText)
                    .foregroundStyle(Color.red)
                    .task(id: warningCount) {
                        guard !warningText.isEmpty else { return }
                        try? await Task.sleep(for: .seconds(1))
                        warningText = ""
                    }
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        
                        TextField("Weight", text: $weightInput)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.decimalPad)
                            .frame(width: geo.size.width * 0.8)
                        Button("Save") {
                            if Double(weightInput) != nil {
                                addWeight(weight: weightInput)
                            } else {
                                showWarning("Please input your weight in number format")
                            }
                            
                        }
                        .frame(width: geo.size.width * 0.2)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal)

                Button {
                    selectedPage = .calorieEstimator
                } label: {
                    Text("Calorie Estimator")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
            .toolbar(.hidden, for: .navigationBar)
            .inspector(isPresented: isShowingDetail) {
                NavigationStack {
                    if let selectedEntry {
                        WeightEntryDetailView(entry: selectedEntry) {
                            self.selectedEntry = nil
                        }
                    } else {
                        ContentUnavailableView(
                            "No Entry Selected",
                            systemImage: "hand.tap",
                            description: Text("Tap a dot on the graph to see its weight and date.")
                        )
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }

    private func showWarning(_ text: String) {
        // The auto-clear is keyed on this counter rather than the text, so repeating the
        // same message restarts the second instead of riding out the previous timer.
        warningText = text
        warningCount += 1
    }

    private func addWeight(weight: String) {
        guard let weightValue = Float(weight) else { return }
        guard weightValue > 0 else {
            showWarning("Please input a weight greater than zero")
            return
        }
        // Two entries on the same day land on the same x position and stack on the graph.
        guard !weights.contains(where: { Calendar.current.isDateInToday($0.date) }) else {
            showWarning("There's already an entry for today")
            return
        }
        let newWeight = WeightItem(weight: weightValue)
        modelContext.insert(newWeight)
        weightInput = ""
    }

    private func deleteWeights(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weights[index])
        }
    }
}

#Preview {
    ContentView(selectedPage: .constant(.main))
        .modelContainer(for: [Item.self, WeightItem.self], inMemory: true)
}
