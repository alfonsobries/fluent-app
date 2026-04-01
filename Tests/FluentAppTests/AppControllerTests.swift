import XCTest
@testable import FluentCore

final class AppControllerTests: XCTestCase {
    func testInitBindsHotKeysAndRebindsOnSettingsChange() {
        let settings = AppSettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let clipboard = MockClipboardService()
        let hotKeys = MockHotKeyManager()
        let controller = AppController(settings: settings, clipboardService: clipboard, hotKeyManager: hotKeys)

        XCTAssertEqual(hotKeys.registeredActionSets.count, 1)

        settings.addAction(ShortcutAction(name: "New", keyCode: 1, modifiers: 256, prompt: "Prompt"))
        XCTAssertEqual(hotKeys.registeredActionSets.count, 2)
        XCTAssertNotNil(hotKeys.onTrigger)
        XCTAssertFalse(controller.isProcessing)
    }

    func testProcessSelectionFailureStates() {
        let provider = StubAIProvider()
        let factory = AIProviderFactory(providers: [.openai: provider])
        let launchController = MockLaunchAtLoginController()
        let suiteName = UUID().uuidString
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let settings = AppSettings(userDefaults: userDefaults, providerFactory: factory, launchAtLoginController: launchController)
        let clipboard = MockClipboardService()
        let hotKeys = MockHotKeyManager()
        let controller = AppController(settings: settings, clipboardService: clipboard, hotKeyManager: hotKeys)
        let action = settings.shortcutActions[0]

        clipboard.permissionGranted = false
        controller.processSelection(with: action)
        XCTAssertEqual(controller.state, .failed("Accessibility permissions are required."))

        clipboard.permissionGranted = true
        settings.setAPIKey("", for: .openai)
        controller.processSelection(with: action)
        XCTAssertEqual(controller.state, .failed("Configure an API key for OpenAI (GPT)."))

        settings.setAPIKey("key", for: .openai)
        clipboard.copiedText = nil
        controller.processSelection(with: action)
        XCTAssertEqual(controller.state, .failed("No text selection was found."))
    }

    func testProcessSelectionSuccessAndHotKeyTrigger() {
        let provider = StubAIProvider()
        let settings = AppSettings(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            providerFactory: AIProviderFactory(providers: [.openai: provider])
        )
        settings.setAPIKey("key", for: .openai)
        let clipboard = MockClipboardService()
        clipboard.copiedText = "Hola"
        let hotKeys = MockHotKeyManager()
        let controller = AppController(settings: settings, clipboardService: clipboard, hotKeyManager: hotKeys)
        let action = settings.shortcutActions[0]
        let expectation = expectation(description: "process")

        provider.nextResult = .success("Hello")
        hotKeys.onTrigger?(action)

        DispatchQueue.main.async {
            XCTAssertEqual(controller.state, .completed(action.name))
            XCTAssertEqual(clipboard.pastedTexts, ["Hello"])
            XCTAssertEqual(provider.receivedTexts, ["Hola"])
            XCTAssertEqual(provider.receivedKeys, ["key"])
            XCTAssertEqual(provider.receivedInstructions, [action.prompt])
            controller.clearTransientState()
            XCTAssertEqual(controller.state, .idle)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testProcessSelectionFailureFromProviderAndBusyGuard() {
        let provider = StubAIProvider()
        provider.nextResult = .failure(.rateLimited)
        let settings = AppSettings(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            providerFactory: AIProviderFactory(providers: [.openai: provider])
        )
        settings.setAPIKey("key", for: .openai)
        let clipboard = MockClipboardService()
        clipboard.copiedText = "Hola"
        let hotKeys = MockHotKeyManager()
        let controller = AppController(settings: settings, clipboardService: clipboard, hotKeyManager: hotKeys)
        let action = settings.shortcutActions[0]
        let expectation = expectation(description: "failure")

        controller.processSelection(with: action)
        controller.processSelection(with: action)

        DispatchQueue.main.async {
            XCTAssertEqual(controller.state, .failed("Rate limited. Please wait and try again."))
            XCTAssertEqual(provider.receivedTexts.count, 1)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testCurrentActionNameReflectsProcessingState() {
        let provider = DelayedStubAIProvider()
        let settings = AppSettings(
            userDefaults: UserDefaults(suiteName: UUID().uuidString)!,
            providerFactory: AIProviderFactory(providers: [.openai: provider])
        )
        settings.setAPIKey("key", for: .openai)
        let clipboard = MockClipboardService()
        clipboard.copiedText = "Hola"
        let controller = AppController(settings: settings, clipboardService: clipboard, hotKeyManager: MockHotKeyManager())
        let action = settings.shortcutActions[0]
        let expectation = expectation(description: "delayed")

        XCTAssertNil(controller.currentActionName)
        controller.processSelection(with: action)
        XCTAssertEqual(controller.currentActionName, action.name)

        provider.completion?(.success("Hello"))

        DispatchQueue.main.async {
            XCTAssertNil(controller.currentActionName)
            expectation.fulfill()
        }

        waitForExpectations(timeout: 1)
    }

    func testAssigningSettingsPublishesNewReference() {
        let originalSettings = AppSettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let controller = AppController(settings: originalSettings, clipboardService: MockClipboardService(), hotKeyManager: MockHotKeyManager())
        let replacement = AppSettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)

        controller.settings = replacement

        XCTAssertTrue(controller.settings === replacement)
    }

    func testPasteErrorMessageOnlyWhenAccessibilityIsGranted() {
        let clipboard = MockClipboardService()
        let controller = AppController(
            settings: AppSettings(userDefaults: UserDefaults(suiteName: UUID().uuidString)!),
            clipboardService: clipboard,
            hotKeyManager: MockHotKeyManager()
        )

        clipboard.permissionGranted = false
        controller.pasteErrorMessageIfPossible("Missing API key")
        XCTAssertEqual(clipboard.promptedValues, [false])
        XCTAssertTrue(clipboard.pastedTexts.isEmpty)

        clipboard.permissionGranted = true
        controller.pasteErrorMessageIfPossible("Missing API key")
        XCTAssertEqual(clipboard.promptedValues, [false, false])
        XCTAssertEqual(clipboard.pastedTexts, ["Fluent App Error: Missing API key"])
    }
}
