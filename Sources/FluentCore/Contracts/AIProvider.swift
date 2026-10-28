import Foundation

public protocol AIProvider {
    static var identifier: String { get }
    static var displayName: String { get }
    static var apiKeyURL: String { get }
    static var apiKeyPlaceholder: String { get }

    func processText(
        text: String,
        apiKey: String,
        model: String,
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

    /// Models offered in Settings, recommended first. Each is the provider's documented
    /// pick for its tier and has no announced retirement.
    public var modelOptions: [AIModelOption] {
        switch self {
        case .openai:
            return [
                AIModelOption(id: "gpt-6-luna", name: "GPT-6 Luna", detail: "Recommended. Fast and inexpensive."),
                AIModelOption(id: "gpt-6-astra", name: "GPT-6 Astra", detail: "Most capable. Slower and more expensive.")
            ]
        case .claude:
            return [
                AIModelOption(id: "claude-haiku-5-5", name: "Claude Haiku 5.5", detail: "Recommended. Fastest and least expensive."),
                AIModelOption(id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5", detail: "Balanced speed and quality."),
                AIModelOption(id: "claude-opus-5-5", name: "Claude Opus 5.5", detail: "Most capable. Slower and more expensive.")
            ]
        case .gemini:
            return [
                AIModelOption(id: "gemini-3.8-flash", name: "Gemini 3.8 Flash", detail: "Recommended. Fast and inexpensive."),
                AIModelOption(id: "gemini-3.5-flash-lite", name: "Gemini 3.5 Flash-Lite", detail: "Lowest cost.")
            ]
        case .grok:
            return [
                AIModelOption(id: "grok-4.7", name: "Grok 4.7", detail: "Recommended. xAI's most capable model."),
                AIModelOption(id: "grok-4.3", name: "Grok 4.3", detail: "Lower cost.")
            ]
        }
    }

    public var defaultModel: String {
        modelOptions[0].id
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

public struct AIModelOption: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let detail: String

    public init(id: String, name: String, detail: String) {
        self.id = id
        self.name = name
        self.detail = detail
    }
}
