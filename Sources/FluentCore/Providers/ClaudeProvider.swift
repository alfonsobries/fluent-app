import Foundation

public final class ClaudeProvider: AIProvider {
    public static let identifier = "claude"
    public static let displayName = "Anthropic (Claude)"
    public static let apiKeyURL = "https://console.anthropic.com/api-keys"
    public static let apiKeyPlaceholder = "sk-ant-..."

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let model: String
    private let apiVersion: String

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        model: String = "claude-3-haiku-20240307",
        apiVersion: String = "2023-06-01"
    ) {
        self.httpClient = httpClient
        self.baseURL = baseURL
        self.model = model
        self.apiVersion = apiVersion
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
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try! JSONSerialization.data(withJSONObject: [
            "model": model,
            "max_tokens": 4096,
            "system": instructions,
            "messages": [["role": "user", "content": text]]
        ])

        perform(request, completion: completion)
    }

    private func perform(
        _ request: URLRequest,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) {
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
                let content = json["content"] as? [[String: Any]],
                let first = content.first?["text"] as? String
            else {
                return .failure(.invalidResponse)
            }
            return .success(first.trimmingCharacters(in: .whitespacesAndNewlines))
        case 401:
            return .failure(.invalidAPIKey)
        case 429:
            return .failure(.rateLimited)
        default:
            return .failure(.serverError(response.1.statusCode))
        }
    }
}
