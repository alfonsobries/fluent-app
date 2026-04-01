import Foundation

public final class GeminiProvider: AIProvider {
    public static let identifier = "gemini"
    public static let displayName = "Google (Gemini)"
    public static let apiKeyURL = "https://aistudio.google.com/apikey"
    public static let apiKeyPlaceholder = "AI..."

    private let httpClient: HTTPClient
    private let model: String

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        model: String = "gemini-1.5-flash"
    ) {
        self.httpClient = httpClient
        self.model = model
    }

    public func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(.invalidAPIKey))
            return
        }

        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(encodedKey)")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "system_instruction": [
                "parts": [["text": instructions]]
            ],
            "contents": [[
                "parts": [["text": text]]
            ]],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 4096
            ]
        ])

        httpClient.send(request) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.networkError(error.localizedDescription)))
            case .success(let response):
                completion(self.mapResponse(response))
            }
        }
    }

    private func mapResponse(_ response: (Data, HTTPURLResponse)) -> Result<String, AIProviderError> {
        switch response.1.statusCode {
        case 200:
            guard !response.0.isEmpty else { return .failure(.noContent) }
            guard
                let json = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
                let candidates = json["candidates"] as? [[String: Any]],
                let content = candidates.first?["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]],
                let text = parts.first?["text"] as? String
            else {
                return .failure(.invalidResponse)
            }
            return .success(text.trimmingCharacters(in: .whitespacesAndNewlines))
        case 400:
            return .failure(.invalidAPIKey)
        case 429:
            return .failure(.rateLimited)
        default:
            return .failure(.serverError(response.1.statusCode))
        }
    }
}
