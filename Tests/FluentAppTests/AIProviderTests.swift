import XCTest
@testable import FluentCore

final class AIProviderTests: XCTestCase {
    func testProviderMetadataAndErrors() {
        XCTAssertEqual(AIProviderType.allCases.map(\.displayName), [
            "OpenAI (GPT)",
            "Anthropic (Claude)",
            "Google (Gemini)",
            "xAI (Grok)"
        ])
        XCTAssertEqual(AIProviderType.openai.id, "openai")
        XCTAssertTrue(AIProviderType.claude.apiKeyURL.contains("anthropic"))
        XCTAssertEqual(AIProviderType.grok.apiKeyPlaceholder, "xai-...")

        XCTAssertEqual(AIProviderError.invalidAPIKey.errorDescription, "Invalid API key. Please check your credentials.")
        XCTAssertEqual(AIProviderError(networkError: TestError.failed), .networkError("boom"))
        XCTAssertEqual(AIProviderError.networkError("boom").errorDescription, "Network error: boom")
        XCTAssertEqual(AIProviderError.invalidResponse.errorDescription, "Invalid response from the AI service.")
        XCTAssertEqual(AIProviderError.rateLimited.errorDescription, "Rate limited. Please wait and try again.")
        XCTAssertEqual(AIProviderError.serverError(500).errorDescription, "Server error (code: 500). Please try again.")
        XCTAssertEqual(AIProviderError.noContent.errorDescription, "No content in response.")
        XCTAssertEqual(AIProviderError.unknown("custom").errorDescription, "custom")
    }

    func testFactoryResolveRegisterAndFallback() {
        let openAIStub = StubAIProvider()
        let claudeStub = StubAIProvider()
        let factory = AIProviderFactory(providers: [.openai: openAIStub])

        XCTAssertTrue(factory.resolve(.claude) is StubAIProvider)
        factory.register(.claude, provider: claudeStub)
        XCTAssertTrue(factory.resolve(.claude) as AnyObject === claudeStub)
        XCTAssertEqual(factory.availableProviders, AIProviderType.allCases)
    }

    func testOpenAIProviderRequestAndResponses() throws {
        let client = MockHTTPClient()
        let provider = OpenAIProvider(httpClient: client)

        assert(provider.processResult(text: "hola", apiKey: "", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .failure(TestError.failed)
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.networkError("boom")))

        client.nextResult = .success((Data(), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.noContent))

        client.nextResult = .success((jsonData(["choices": []]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidResponse))

        client.nextResult = .success((jsonData(["choices": [["message": ["content": " hello "]]]]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .success("hello"))

        client.nextResult = .success((Data(), httpResponse(statusCode: 401)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .success((Data(), httpResponse(statusCode: 429)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.rateLimited))

        client.nextResult = .success((Data(), httpResponse(statusCode: 503)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.serverError(503)))

        let request = try XCTUnwrap(client.requests.last)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer key")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testClaudeProviderRequestAndResponses() throws {
        let client = MockHTTPClient()
        let provider = ClaudeProvider(httpClient: client)

        assert(provider.processResult(text: "hola", apiKey: "", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .failure(TestError.failed)
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.networkError("boom")))

        client.nextResult = .success((Data(), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.noContent))

        client.nextResult = .success((jsonData(["content": []]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidResponse))

        client.nextResult = .success((jsonData(["content": [["text": " bonjour "]]]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .success("bonjour"))

        client.nextResult = .success((Data(), httpResponse(statusCode: 401)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .success((Data(), httpResponse(statusCode: 429)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.rateLimited))

        client.nextResult = .success((Data(), httpResponse(statusCode: 500)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.serverError(500)))

        let request = try XCTUnwrap(client.requests.last)
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
    }

    func testGeminiProviderRequestAndResponses() throws {
        let client = MockHTTPClient()
        let provider = GeminiProvider(httpClient: client)

        assert(provider.processResult(text: "hola", apiKey: "", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .failure(TestError.failed)
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.networkError("boom")))

        client.nextResult = .success((Data(), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.noContent))

        client.nextResult = .success((jsonData(["candidates": []]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidResponse))

        client.nextResult = .success((jsonData([
            "candidates": [[
                "content": [
                    "parts": [["text": " resumen "]]
                ]
            ]]
        ]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .success("resumen"))

        client.nextResult = .success((Data(), httpResponse(statusCode: 400)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .success((Data(), httpResponse(statusCode: 429)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.rateLimited))

        client.nextResult = .success((Data(), httpResponse(statusCode: 500)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.serverError(500)))

        let request = try XCTUnwrap(client.requests.last)
        XCTAssertTrue(request.url?.absoluteString.contains("models/gemini-1.5-flash:generateContent?key=key") == true)
    }

    func testGrokProviderRequestAndResponses() throws {
        let client = MockHTTPClient()
        let provider = GrokProvider(httpClient: client)

        assert(provider.processResult(text: "hola", apiKey: "", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .failure(TestError.failed)
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.networkError("boom")))

        client.nextResult = .success((Data(), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.noContent))

        client.nextResult = .success((jsonData(["choices": []]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidResponse))

        client.nextResult = .success((jsonData(["choices": [["message": ["content": " rewrite "]]]]), httpResponse(statusCode: 200)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .success("rewrite"))

        client.nextResult = .success((Data(), httpResponse(statusCode: 401)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.invalidAPIKey))

        client.nextResult = .success((Data(), httpResponse(statusCode: 429)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.rateLimited))

        client.nextResult = .success((Data(), httpResponse(statusCode: 500)))
        assert(provider.processResult(text: "hola", apiKey: "key", instructions: "inst"), equals: .failure(.serverError(500)))

        let request = try XCTUnwrap(client.requests.last)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer key")
    }

    private func httpResponse(statusCode: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private func assert(_ result: Result<String, AIProviderError>, equals expected: Result<String, AIProviderError>, file: StaticString = #file, line: UInt = #line) {
        switch (result, expected) {
        case (.success(let lhs), .success(let rhs)):
            XCTAssertEqual(lhs, rhs, file: file, line: line)
        case (.failure(let lhs), .failure(let rhs)):
            XCTAssertEqual(lhs, rhs, file: file, line: line)
        default:
            XCTFail("Results did not match", file: file, line: line)
        }
    }
}

private extension AIProvider {
    func processResult(text: String, apiKey: String, instructions: String) -> Result<String, AIProviderError> {
        let expectation = XCTestExpectation(description: "provider")
        var captured: Result<String, AIProviderError>!

        processText(text: text, apiKey: apiKey, instructions: instructions) { result in
            captured = result
            expectation.fulfill()
        }

        XCTWaiter().wait(for: [expectation], timeout: 1)
        return captured
    }
}
