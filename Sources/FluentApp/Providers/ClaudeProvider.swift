import Foundation

/// Anthropic Claude implementation of AIProvider
final class ClaudeProvider: AIProvider {
    static let identifier = "claude"
    static let displayName = "Anthropic (Claude)"
    static let apiKeyURL = "https://console.anthropic.com/api-keys"
    static let apiKeyPlaceholder = "sk-ant-..."

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-haiku-20240307"
    private let apiVersion = "2023-06-01"

    func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) {
        guard !apiKey.isEmpty else {
            completion(.failure(.invalidAPIKey))
            return
        }

        guard let url = URL(string: baseURL) else {
            completion(.failure(.unknown("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": instructions,
            "messages": [
                ["role": "user", "content": text]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.unknown("Failed to encode request")))
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200:
                guard let data = data else {
                    completion(.failure(.noContent))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let content = json["content"] as? [[String: Any]],
                       let firstBlock = content.first,
                       let text = firstBlock["text"] as? String {
                        completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        completion(.failure(.invalidResponse))
                    }
                } catch {
                    completion(.failure(.invalidResponse))
                }

            case 401:
                completion(.failure(.invalidAPIKey))
            case 429:
                completion(.failure(.rateLimited))
            default:
                completion(.failure(.serverError(httpResponse.statusCode)))
            }
        }.resume()
    }
}
