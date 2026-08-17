import SwiftUI
import SwiftData
import PhotosUI

private let geminiAPIKey = "AQ.Ab8RN6KTLznHf8PmxmO0VEbvwWTXWHoNAkkGDicTOjlo-GKPOg"

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { var text: String }
            var parts: [Part]
        }
        var content: Content
    }
    var candidates: [Candidate]     
}

struct NutritionInfo: Codable {
    let calories: Int
    let proteinPercent: Double
    let carbsPercent: Double
    let fatPercent: Double
    let fiberPercent: Double
    let advice: String
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @Query(sort: \WeightItem.date, order: .forward) var weights: [WeightItem]
    @Binding var selectedPage: Page
    @State private var weightInput: String = ""
    @State private var warningText: String = ""
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
                Spacer()

                WeightGraphView(weights: weights, selectedEntry: $selectedEntry)
                    .frame(height: 260)

                Text(warningText)
                    .foregroundStyle(Color.red)
                    .task(id: warningText) {
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
                                weightInput = ""
                            } else {
                                warningText = "Please input your weight in number format"
                            }
                            
                        }
                        .frame(width: geo.size.width * 0.2)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal)

                Spacer()
            }
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

    private func addWeight(weight: String) {
        guard let weightValue = Float(weight) else { return }
        let newWeight = WeightItem(weight: weightValue)
        modelContext.insert(newWeight)
    }

    private func deleteWeights(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(weights[index])
        }
    }

    func loadPhoto(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    func getCalories(from image: UIImage) async throws -> NutritionInfo {
        let imageData = image.jpegData(compressionQuality: 0.8)!

        let prompt = """
        Analyze the food in this image. Respond ONLY with valid JSON, no extra text, in this exact format:
        {
          "calories": <estimated total calories as an integer>,
          "proteinPercent": <protein as % of recommended daily value as a number>,
          "carbsPercent": <carbs as % of recommended daily value as a number>,
          "fatPercent": <fat as % of recommended daily value as a number>,
          "fiberPercent": <fiber as % of recommended daily value as a number>,
          "advice": "<specific advice on how to balance this meal and what to eat alongside it>"
        }
        """

        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(geminiAPIKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]
            ]]]
        ])

        let (data, _) = try await URLSession.shared.data(for: request)
        let responseText = try JSONDecoder().decode(GeminiResponse.self, from: data).candidates.first!.content.parts.first!.text
        let jsonData = responseText.data(using: .utf8)!
        return try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
    }
}

#Preview {
    ContentView(selectedPage: .constant(.main))
        .modelContainer(for: [Item.self, WeightItem.self], inMemory: true)
}
