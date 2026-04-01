import Foundation

public final class GrokProvider: AIProvider {
    public static let identifier = "grok"
    public static let displayName = "xAI (Grok)"
    public static let apiKeyURL = "https://console.x.ai"
    public static let apiKeyPlaceholder = "xai-..."

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let model: String

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.x.ai/v1/chat/completions")!,
        model: String = "grok-beta"
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
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

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
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
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                return .failure(.invalidResponse)
            }
            return .success(content.trimmingCharacters(in: .whitespacesAndNewlines))
        case 401:
            return .failure(.invalidAPIKey)
        case 429:
            return .failure(.rateLimited)
        default:
            return .failure(.serverError(response.1.statusCode))
        }
    }
}
