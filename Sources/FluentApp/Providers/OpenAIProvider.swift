import Foundation

/// OpenAI GPT implementation of AIProvider
final class OpenAIProvider: AIProvider {
    static let identifier = "openai"
    static let displayName = "OpenAI (GPT)"
    static let apiKeyURL = "https://platform.openai.com/api-keys"
    static let apiKeyPlaceholder = "sk-..."

    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini"

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
