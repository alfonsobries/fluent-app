import Foundation

public protocol AIProvider {
    static var identifier: String { get }
    static var displayName: String { get }
    static var apiKeyURL: String { get }
    static var apiKeyPlaceholder: String { get }

    func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    )
}

public enum AIProviderError: Error, LocalizedError, Equatable {
    case invalidAPIKey
    case networkError(String)
    case invalidResponse
    case rateLimited
    case serverError(Int)
    case noContent
    case unknown(String)

    public init(networkError error: Error) {
        self = .networkError(error.localizedDescription)
    }

    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .networkError(let description):
            return "Network error: \(description)"
        case .invalidResponse:
            return "Invalid response from the AI service."
        case .rateLimited:
            return "Rate limited. Please wait and try again."
        case .serverError(let code):
            return "Server error (code: \(code)). Please try again."
        case .noContent:
            return "No content in response."
        case .unknown(let message):
            return message
        }
    }
}

public enum AIProviderType: String, CaseIterable, Codable, Identifiable {
    case openai
    case claude
    case gemini
    case grok

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .openai: return "OpenAI (GPT)"
        case .claude: return "Anthropic (Claude)"
        case .gemini: return "Google (Gemini)"
        case .grok: return "xAI (Grok)"
        }
    }

    public var apiKeyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .claude: return "https://console.anthropic.com/api-keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .grok: return "https://console.x.ai"
        }
    }

    public var apiKeyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .claude: return "sk-ant-..."
        case .gemini: return "AI..."
        case .grok: return "xai-..."
        }
    }
}
