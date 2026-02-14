import Foundation

final class TextProcessor {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    func process(text: String, rulePrompt: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": rulePrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.3
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ProcessorError.apiError(errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw ProcessorError.decodingError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum ProcessorError: Error, LocalizedError {
        case apiError(String)
        case decodingError

        var errorDescription: String? {
            switch self {
            case .apiError(let msg): return "GPT API error: \(msg)"
            case .decodingError: return "Failed to decode GPT response"
            }
        }
    }
}
