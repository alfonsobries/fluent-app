import Foundation
@testable import FluentCore

final class MockHTTPClient: HTTPClient {
    var requests: [URLRequest] = []
    var nextResult: Result<(Data, HTTPURLResponse), Error>?

    func send(
        _ request: URLRequest,
        completion: @escaping (Result<(Data, HTTPURLResponse), Error>) -> Void
    ) {
        requests.append(request)
        completion(nextResult ?? .failure(NSError(domain: "MockHTTPClient", code: -1)))
    }
}

final class MockClipboardService: ClipboardServicing {
    var permissionGranted = true
    var copiedText: String?
    var pastedTexts: [String] = []
    var promptedValues: [Bool] = []

    func checkAccessibilityPermissions(prompt: Bool) -> Bool {
        promptedValues.append(prompt)
        return permissionGranted
    }

    func copySelectedText() -> String? {
        copiedText
    }

    func pasteText(_ text: String) {
        pastedTexts.append(text)
    }
}

final class MockHotKeyManager: HotKeyManaging {
    var isPaused = false
    var onTrigger: ((ShortcutAction) -> Void)?
    var registeredActionSets: [[ShortcutAction]] = []
    var unregisterCallCount = 0

    func registerHotKeys(for actions: [ShortcutAction]) {
        registeredActionSets.append(actions)
    }

    func unregisterAllHotKeys() {
        unregisterCallCount += 1
    }
}

final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var isEnabled: Bool
    var receivedValues: [Bool] = []
    var error: Error?

    init(isEnabled: Bool = false, error: Error? = nil) {
        self.isEnabled = isEnabled
        self.error = error
    }

    func setEnabled(_ enabled: Bool) throws {
        receivedValues.append(enabled)
        if let error {
            throw error
        }
        isEnabled = enabled
    }
}

final class StubAIProvider: AIProvider {
    static let identifier = "stub"
    static let displayName = "Stub"
    static let apiKeyURL = "https://example.com"
    static let apiKeyPlaceholder = "stub"

    var nextResult: Result<String, AIProviderError> = .success("done")
    var receivedTexts: [String] = []
    var receivedKeys: [String] = []
    var receivedInstructions: [String] = []

    func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) {
        receivedTexts.append(text)
        receivedKeys.append(apiKey)
        receivedInstructions.append(instructions)
        completion(nextResult)
    }
}

final class DelayedStubAIProvider: AIProvider {
    static let identifier = "delayed"
    static let displayName = "Delayed"
    static let apiKeyURL = "https://example.com"
    static let apiKeyPlaceholder = "delayed"

    var completion: ((Result<String, AIProviderError>) -> Void)?

    func processText(
        text: String,
        apiKey: String,
        instructions: String,
        completion: @escaping (Result<String, AIProviderError>) -> Void
    ) {
        self.completion = completion
    }
}

enum TestError: Error, LocalizedError {
    case failed

    var errorDescription: String? {
        "boom"
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else { return }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
