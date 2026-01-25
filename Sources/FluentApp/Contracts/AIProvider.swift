import Foundation

/// Protocol that defines the contract for AI text processing providers
/// Similar to Laravel's Contract pattern - any AI provider must implement this interface
protocol AIProvider {
    /// Unique identifier for the provider
    static var identifier: String { get }

    /// Display name for the UI
    static var displayName: String { get }

    /// URL to get an API key
    static var apiKeyURL: String { get }

    /// Placeholder text for API key input
    static var apiKeyPlaceholder: String { get }

    /// Process text with the given instructions
    /// - Parameters:
    ///   - text: The text to process
    ///   - apiKey: The API key for authentication
    ///   - instructions: The system prompt/instructions
    ///   - completion: Callback with the result
    func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    )
}

/// Errors that can occur during AI processing
enum AIProviderError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case serverError(Int)
    case noContent
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your credentials."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
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

/// Enum of available AI providers
enum AIProviderType: String, CaseIterable, Codable {
    case openai = "openai"
    case claude = "claude"
    case gemini = "gemini"
    case grok = "grok"

    var displayName: String {
        switch self {
        case .openai: return "OpenAI (GPT)"
        case .claude: return "Anthropic (Claude)"
        case .gemini: return "Google (Gemini)"
        case .grok: return "xAI (Grok)"
        }
    }

    var apiKeyURL: String {
        switch self {
        case .openai: return "https://platform.openai.com/api-keys"
        case .claude: return "https://console.anthropic.com/api-keys"
        case .gemini: return "https://aistudio.google.com/apikey"
        case .grok: return "https://console.x.ai"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .openai: return "sk-..."
        case .claude: return "sk-ant-..."
        case .gemini: return "AI..."
        case .grok: return "xai-..."
        }
    }
}
