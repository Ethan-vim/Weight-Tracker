import SwiftUI
import PhotosUI

private let geminiAPIKey = "AQ.Ab8RN6L3mTHn6Qqm591rHkBPLKtIoGIwYDHZeZ9gCF4NzmwH8Q"
// ListModels still advertises retired models, so this has to match what the key may
// actually call rather than what the catalog lists.
private let geminiModel = "gemini-3.5-flash"

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
    case serverOverloaded
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            return "That photo could not be read. Try a different one."
        case .requestFailed(let statusCode):
            return "The estimate request failed (\(statusCode)). Try again."
        case .serverOverloaded:
            return "Gemini API is under high load, try again later"
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

    static func getCalories(from image: UIImage, goal: String) async throws -> NutritionInfo {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NutritionError.imageEncodingFailed
        }

        // Naming each dish or product before estimating anchors the numbers to something real
        // instead of a guess from the picture alone, and the daily values are spelled out so the
        // percentages mean the same thing on every run. Kept short because the model reasons on
        // its own, and every extra instruction is latency the user waits through.
        // Only present when the user actually set a goal: an empty goal line is noise the model
        // still spends latency reading.
        let trimmedGoal = goal.trimmingCharacters(in: .whitespacesAndNewlines)
        let goalLine = trimmedGoal.isEmpty
            ? ""
            : "The person's goal is: \(trimmedGoal). Aim the advice at that goal, and do not let it change the calorie or nutrient estimates.\n"

        let prompt = """
        Identify every distinct food and drink in this image.
        For anything packaged, identify the brand and product and use its published nutrition facts, scaled to the amount actually shown rather than to one serving.
        For anything else, name the dish and scale its typical values to the portion shown, judging the amount from what holds it (a small bowl, a full bowl, a plate, a pan) and from anything in frame that gives scale, such as cutlery or a hand.
        Count the cooking oil, butter, sauce and dressing that add calories without being visible.
        The figures below are the total across everything shown.
        \(goalLine)Respond ONLY with valid JSON, no extra text, in this exact format:
        {
          "calories": <estimated total calories as an integer>,
          "proteinPercent": <protein as % of the 50 g daily value, as a number>,
          "carbsPercent": <carbs as % of the 275 g daily value, as a number>,
          "fatPercent": <fat as % of the 78 g daily value, as a number>,
          "fiberPercent": <fiber as % of the 28 g daily value, as a number>,
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

        let data = try await send(request)

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

    /// Sends the request and hands back the body of a successful response, absorbing server
    /// failures that clear on their own so a blip never reaches the user.
    private static func send(_ request: URLRequest) async throws -> Data {
        // 500/502/503/504 mean the model server is overloaded or briefly unavailable, and the
        // identical request usually succeeds moments later. Every other status is deterministic,
        // including the 429 that on this project means the prepayment credits are depleted and
        // will not come back in seconds, so retrying those would only delay the same error.
        let retryableStatusCodes: Set<Int> = [500, 502, 503, 504]
        // The original attempt plus one retry per backoff, keeping the worst added wait near 3s
        // so an interactive estimate never sits there.
        let backoffs: [Duration] = [.seconds(1), .seconds(2)]
        var retriesUsed = 0

        while true {
            let (data, response) = try await URLSession.shared.data(for: request)

            // An error payload decodes as neither a candidate list nor nutrition JSON, so the status
            // code is the only thing that yields a message worth showing.
            if let statusCode = (response as? HTTPURLResponse)?.statusCode, statusCode != 200 {
                guard retryableStatusCodes.contains(statusCode), retriesUsed < backoffs.count else {
                    // A 503 only reaches here once every retry has already failed, so the load is
                    // not clearing in seconds and the user is told to come back later rather than
                    // handed a bare status code to interpret.
                    if statusCode == 503 { throw NutritionError.serverOverloaded }
                    throw NutritionError.requestFailed(statusCode)
                }
                // Task.sleep stays cancellable, so tearing down the caller's Task still ends the
                // estimate right away instead of after the backoff.
                try await Task.sleep(for: backoffs[retriesUsed])
                retriesUsed += 1
                continue
            }

            return data
        }
    }

    /// Gemini often wraps its answer in a ```json fence even when asked for bare JSON, which the
    /// decoder cannot parse.
    private static func unfenced(_ text: String) -> String {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.hasPrefix("```") else { return body }
        body.removeFirst(3)

        // The language tag runs to the end of the line, except when the model doesn't break the
        // line at all — then the JSON starts on it, so stop at whichever comes first.
        if let bodyStart = body.firstIndex(where: { $0 == "{" || $0 == "\n" }) {
            body = String(body[bodyStart...])
        }
        if let closingFence = body.range(of: "```", options: .backwards) {
            body = String(body[..<closingFence.lowerBound])
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
