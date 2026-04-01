import Foundation

public final class AIProviderFactory {
    public static let live = AIProviderFactory()

    private var providers: [AIProviderType: AIProvider]

    public init(providers: [AIProviderType: AIProvider] = [
        .openai: OpenAIProvider(),
        .claude: ClaudeProvider(),
        .gemini: GeminiProvider(),
        .grok: GrokProvider()
    ]) {
        self.providers = providers
    }

    public func register(_ type: AIProviderType, provider: AIProvider) {
        providers[type] = provider
    }

    public func resolve(_ type: AIProviderType) -> AIProvider {
        providers[type] ?? providers[.openai]!
    }

    public var availableProviders: [AIProviderType] {
        AIProviderType.allCases
    }
}
