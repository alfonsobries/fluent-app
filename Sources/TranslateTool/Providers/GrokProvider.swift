import Foundation

/// xAI Grok implementation of AIProvider
/// Grok uses an OpenAI-compatible API format
final class GrokProvider: AIProvider {
    static let identifier = "grok"
    static let displayName = "xAI (Grok)"
    static let apiKeyURL = "https://console.x.ai"
    static let apiKeyPlaceholder = "xai-..."

    private let baseURL = "https://api.x.ai/v1/chat/completions"
    private let model = "grok-beta"

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
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Grok uses OpenAI-compatible format
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": text]
            ],
            "temperature": 0.7
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
                    // OpenAI-compatible response format
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        completion(.success(content.trimmingCharacters(in: .whitespacesAndNewlines)))
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
