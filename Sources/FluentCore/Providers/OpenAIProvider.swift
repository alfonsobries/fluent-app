import Foundation

public final class OpenAIProvider: AIProvider {
    public static let identifier = "openai"
    public static let displayName = "OpenAI (GPT)"
    public static let apiKeyURL = "https://platform.openai.com/api-keys"
    public static let apiKeyPlaceholder = "sk-..."

    private let httpClient: HTTPClient
    private let baseURL: URL
    private let model: String

    public init(
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
        model: String = "gpt-4o-mini"
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

        perform(request, completion: completion) { json in
            guard
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else {
                return nil
            }

            return content
        }
    }

    private func perform(
        _ request: URLRequest,
        completion: @escaping (Result<String, AIProviderError>) -> Void,
        parser: @escaping ([String: Any]) -> String?
    ) {
        httpClient.send(request) { result in
            switch result {
            case .failure(let error):
                completion(.failure(.networkError(error.localizedDescription)))
            case .success(let response):
                completion(self.mapResponse(response, parser: parser))
            }
        }
    }

    private func mapResponse(
        _ response: (Data, HTTPURLResponse),
        parser: ([String: Any]) -> String?
    ) -> Result<String, AIProviderError> {
        switch response.1.statusCode {
        case 200:
            guard !response.0.isEmpty else { return .failure(.noContent) }
            guard
                let json = try? JSONSerialization.jsonObject(with: response.0) as? [String: Any],
                let content = parser(json)
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
