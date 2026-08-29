import SwiftUI
import PhotosUI

private let geminiAPIKey = "AQ.Ab8RN6L3mTHn6Qqm591rHkBPLKtIoGIwYDHZeZ9gCF4NzmwH8Q"
// ListModels still advertises retired models, so this has to match what the key may
// actually call rather than what the catalog lists.
private let geminiModel = "gemini-3.6-flash"

private struct GeminiResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { var text: String? }
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

enum NutritionError: LocalizedError {
    case imageEncodingFailed
    case requestFailed(Int)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "That photo could not be read. Try a different one."
        case .requestFailed(let statusCode):
            return "The estimate request failed (\(statusCode)). Try again."
        case .emptyResponse:
            return "The estimate came back empty. Try again."
        }
    }
}

struct NutritionService {
    static func loadPhoto(from item: PhotosPickerItem) async -> UIImage? {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return nil }
        return image
    }

    static func getCalories(from image: UIImage) async throws -> NutritionInfo {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NutritionError.imageEncodingFailed
        }

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

        var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModel):generateContent?key=\(geminiAPIKey)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "contents": [["parts": [
                ["text": prompt],
                ["inline_data": ["mime_type": "image/jpeg", "data": imageData.base64EncodedString()]]
            ]]]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)

        // An error payload decodes as neither a candidate list nor nutrition JSON, so the status
        // code is the only thing that yields a message worth showing.
        if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode != 200 {
            throw NutritionError.requestFailed(statusCode)
        }

        let parts = try JSONDecoder()
            .decode(GeminiResponse.self, from: data)
            .candidates.first?.content.parts ?? []

        // Thinking models mix in parts carrying no text, and can split one answer across
        // several, so drop the empty ones and join rather than trusting the first part.
        let responseText = parts.compactMap(\.text).joined()
        guard !responseText.isEmpty else {
            throw NutritionError.emptyResponse
        }

        guard let jsonData = unfenced(responseText).data(using: .utf8) else {
            throw NutritionError.emptyResponse
        }

        return try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
    }

    /// Gemini often wraps its answer in a ```json fence even when asked for bare JSON, which the
    /// decoder cannot parse.
    private static func unfenced(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.hasPrefix("```") else { return body }

        if let openingLineBreak = body.firstIndex(of: "\n") {
            body = String(body[body.index(after: openingLineBreak)...])
        }
        if let closingFence = body.range(of: "```", options: .backwards) {
            body = String(body[..<closingFence.lowerBound])
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
