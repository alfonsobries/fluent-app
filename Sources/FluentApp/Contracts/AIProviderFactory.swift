import Foundation

/// Factory class that resolves AIProvider implementations
/// Similar to Laravel's Service Container - resolves contracts to concrete implementations
final class AIProviderFactory {
    static let shared = AIProviderFactory()

    private var providers: [AIProviderType: AIProvider] = [:]

    private init() {
        // Register all available providers
        register(.openai, provider: OpenAIProvider())
        register(.claude, provider: ClaudeProvider())
        register(.gemini, provider: GeminiProvider())
        register(.grok, provider: GrokProvider())
    }

    /// Register a provider implementation
    func register(_ type: AIProviderType, provider: AIProvider) {
        providers[type] = provider
    }

    /// Resolve a provider by type
    /// - Parameter type: The provider type to resolve
    /// - Returns: The concrete implementation of AIProvider
    func resolve(_ type: AIProviderType) -> AIProvider {
        guard let provider = providers[type] else {
            // Default to OpenAI if provider not found
            return providers[.openai]!
        }
        return provider
    }

    /// Get all available provider types
    var availableProviders: [AIProviderType] {
        AIProviderType.allCases
    }
}
