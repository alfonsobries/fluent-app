import Foundation

/// Google Gemini implementation of AIProvider
final class GeminiProvider: AIProvider {
    static let identifier = "gemini"
    static let displayName = "Google (Gemini)"
    static let apiKeyURL = "https://aistudio.google.com/apikey"
    static let apiKeyPlaceholder = "AI..."

    private let model = "gemini-1.5-flash"

    private func baseURL(apiKey: String) -> String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }

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

        guard let url = URL(string: baseURL(apiKey: apiKey)) else {
            completion(.failure(.unknown("Invalid URL")))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Gemini uses a different structure - system instruction + user content
        let body: [String: Any] = [
            "system_instruction": [
                "parts": [
                    ["text": instructions]
                ]
            ],
            "contents": [
                [
                    "parts": [
                        ["text": text]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 4096
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
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                    } else {
                        completion(.failure(.invalidResponse))
                    }
                } catch {
                    completion(.failure(.invalidResponse))
                }

            case 400:
                completion(.failure(.invalidAPIKey))
            case 429:
                completion(.failure(.rateLimited))
            default:
                completion(.failure(.serverError(httpResponse.statusCode)))
            }
        }.resume()
    }
}
