import XCTest

// Test AIProviderType and AIProviderError

enum TestAIProviderType: String, CaseIterable, Codable {
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

enum TestAIProviderError: Error, LocalizedError {
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

final class AIProviderTests: XCTestCase {

    func testAllProvidersExist() {
        XCTAssertEqual(TestAIProviderType.allCases.count, 4)
        XCTAssertTrue(TestAIProviderType.allCases.contains(.openai))
        XCTAssertTrue(TestAIProviderType.allCases.contains(.claude))
        XCTAssertTrue(TestAIProviderType.allCases.contains(.gemini))
        XCTAssertTrue(TestAIProviderType.allCases.contains(.grok))
    }

    func testProviderDisplayNames() {
        XCTAssertEqual(TestAIProviderType.openai.displayName, "OpenAI (GPT)")
        XCTAssertEqual(TestAIProviderType.claude.displayName, "Anthropic (Claude)")
        XCTAssertEqual(TestAIProviderType.gemini.displayName, "Google (Gemini)")
        XCTAssertEqual(TestAIProviderType.grok.displayName, "xAI (Grok)")
    }

    func testProviderAPIKeyURLs() {
        XCTAssertTrue(TestAIProviderType.openai.apiKeyURL.contains("openai.com"))
        XCTAssertTrue(TestAIProviderType.claude.apiKeyURL.contains("anthropic.com"))
        XCTAssertTrue(TestAIProviderType.gemini.apiKeyURL.contains("google"))
        XCTAssertTrue(TestAIProviderType.grok.apiKeyURL.contains("x.ai"))
    }

    func testProviderPlaceholders() {
        XCTAssertTrue(TestAIProviderType.openai.apiKeyPlaceholder.starts(with: "sk-"))
        XCTAssertTrue(TestAIProviderType.claude.apiKeyPlaceholder.starts(with: "sk-ant-"))
        XCTAssertTrue(TestAIProviderType.gemini.apiKeyPlaceholder.starts(with: "AI"))
        XCTAssertTrue(TestAIProviderType.grok.apiKeyPlaceholder.starts(with: "xai-"))
    }

    func testProviderTypeCodable() throws {
        let provider = TestAIProviderType.claude

        let encoder = JSONEncoder()
        let data = try encoder.encode(provider)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestAIProviderType.self, from: data)

        XCTAssertEqual(provider, decoded)
    }

    func testProviderTypeRawValue() {
        XCTAssertEqual(TestAIProviderType.openai.rawValue, "openai")
        XCTAssertEqual(TestAIProviderType.claude.rawValue, "claude")
        XCTAssertEqual(TestAIProviderType.gemini.rawValue, "gemini")
        XCTAssertEqual(TestAIProviderType.grok.rawValue, "grok")
    }

    func testErrorDescriptions() {
        XCTAssertNotNil(TestAIProviderError.invalidAPIKey.errorDescription)
        XCTAssertNotNil(TestAIProviderError.invalidResponse.errorDescription)
        XCTAssertNotNil(TestAIProviderError.rateLimited.errorDescription)
        XCTAssertNotNil(TestAIProviderError.noContent.errorDescription)

        let serverError = TestAIProviderError.serverError(500)
        XCTAssertTrue(serverError.errorDescription?.contains("500") ?? false)

        let unknownError = TestAIProviderError.unknown("Custom error")
        XCTAssertEqual(unknownError.errorDescription, "Custom error")
    }
}
