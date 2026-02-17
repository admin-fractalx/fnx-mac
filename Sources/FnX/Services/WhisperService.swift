import Foundation

public final class WhisperService {
    public init() {}

    public func transcribe(fileURL: URL, translate: Bool = false) async throws -> String {
        let apiKey = Secrets.openAIAPIKey

        let endpoint = translate
            ? "https://api.openai.com/v1/audio/translations"
            : "https://api.openai.com/v1/audio/transcriptions"

        guard let url = URL(string: endpoint) else {
            throw WhisperError.invalidEndpoint
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)

        var body = Data()

        // file field
        body.appendMultipart("--\(boundary)\r\n")
        body.appendMultipart("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        body.appendMultipart("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.appendMultipart("\r\n")

        // model field
        body.appendMultipart("--\(boundary)\r\n")
        body.appendMultipart("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.appendMultipart("whisper-1\r\n")

        // response_format field
        body.appendMultipart("--\(boundary)\r\n")
        body.appendMultipart("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        body.appendMultipart("text\r\n")

        // closing boundary
        body.appendMultipart("--\(boundary)--\r\n")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text
    }

    public enum WhisperError: Error, LocalizedError {
        case invalidEndpoint
        case invalidResponse
        case apiError(statusCode: Int, message: String)

        public var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Invalid API endpoint"
            case .invalidResponse:
                return "Invalid response from server"
            case .apiError(let statusCode, let message):
                return "API error (\(statusCode)): \(message)"
            }
        }
    }
}

private extension Data {
    mutating func appendMultipart(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
