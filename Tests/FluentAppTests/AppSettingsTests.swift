import XCTest
@testable import FluentCore

final class AppSettingsTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "FluentAppTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsLoadAndPersist() {
        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.selectedProvider, .openai)
        XCTAssertEqual(settings.shortcutActions.count, 3)
        XCTAssertTrue(settings.launchAtStartup)
        XCTAssertEqual(userDefaults.bool(forKey: AppSettings.Keys.launchAtStartup), true)

        settings.selectedProvider = .claude
        settings.setAPIKey("  abc123  ", for: .claude)

        XCTAssertEqual(userDefaults.string(forKey: AppSettings.Keys.selectedProvider), "claude")
        let apiKeys = userDefaults.dictionary(forKey: AppSettings.Keys.apiKeys) as? [String: String]
        XCTAssertEqual(apiKeys?["claude"], "abc123")
        XCTAssertEqual(settings.currentAPIKey, "abc123")
    }

    func testLoadsSavedProviderAPIKeysAndActions() throws {
        userDefaults.set("grok", forKey: AppSettings.Keys.selectedProvider)
        userDefaults.set(["openai": "one", "grok": "two"], forKey: AppSettings.Keys.apiKeys)
        let savedAction = ShortcutAction(name: "Saved", keyCode: 12, modifiers: 256, prompt: "Prompt")
        userDefaults.set(try JSONEncoder().encode([savedAction]), forKey: AppSettings.Keys.shortcutActions)
        userDefaults.set(false, forKey: AppSettings.Keys.launchAtStartup)

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.selectedProvider, .grok)
        XCTAssertEqual(settings.apiKeys[.openai], "one")
        XCTAssertEqual(settings.apiKeys[.grok], "two")
        XCTAssertEqual(settings.shortcutActions, [savedAction])
        XCTAssertFalse(settings.launchAtStartup)
    }

    func testLaunchAtStartupIntegrationAndError() {
        let successController = MockLaunchAtLoginController(isEnabled: true)
        let settings = AppSettings(userDefaults: userDefaults, launchAtLoginController: successController)

        XCTAssertTrue(settings.isLaunchAtStartupEnabled)

        settings.launchAtStartup = false
        XCTAssertEqual(successController.receivedValues, [false])

        let failingController = MockLaunchAtLoginController(error: TestError.failed)
        let failingSettings = AppSettings(userDefaults: userDefaults, launchAtLoginController: failingController)
        failingSettings.launchAtStartup = false

        XCTAssertEqual(failingSettings.launchAtStartupError, "boom")
    }

    func testLaunchAtStartupDefaultSynchronizesOnFirstLaunch() {
        let controller = MockLaunchAtLoginController(isEnabled: false)

        let settings = AppSettings(userDefaults: userDefaults, launchAtLoginController: controller)

        XCTAssertTrue(settings.launchAtStartup)
        XCTAssertEqual(controller.receivedValues, [true])
        XCTAssertTrue(controller.isEnabled)
    }

    func testActionCrudAndLookup() {
        let provider = StubAIProvider()
        let factory = AIProviderFactory(providers: [.openai: provider])
        let settings = AppSettings(userDefaults: userDefaults, providerFactory: factory)
        let added = settings.addAction(from: ShortcutCatalog.templates[3])

        XCTAssertTrue(settings.currentProvider as AnyObject === provider)
        XCTAssertEqual(settings.actionForHotKey(keyCode: added.keyCode, modifiers: added.modifiers)?.name, "Summarize")

        var updated = added
        updated.name = "TL;DR"
        settings.updateAction(updated)
        XCTAssertEqual(settings.shortcutActions.first(where: { $0.id == updated.id })?.name, "TL;DR")
        settings.updateAction(ShortcutAction(name: "Ghost", keyCode: 2, modifiers: 256, prompt: "Prompt"))

        settings.moveAction(from: IndexSet(integer: settings.shortcutActions.count - 1), to: 0)
        XCTAssertEqual(settings.shortcutActions.first?.id, updated.id)

        settings.deleteAction(updated)
        XCTAssertNil(settings.shortcutActions.first(where: { $0.id == updated.id }))

        settings.resetToDefaults()
        XCTAssertEqual(settings.shortcutActions.map(\.name), ["Translate", "Improve Writing", "Fix Grammar"])
        XCTAssertEqual(settings.enabledActions.count, 2)
    }

    func testShortcutChangeCallbackAndLegacyMigration() throws {
        userDefaults.set("legacy-key", forKey: AppSettings.Keys.legacyAPIKey)
        userDefaults.set(UInt32(12), forKey: AppSettings.Keys.legacyShortcutKeyCode)
        userDefaults.set(UInt32(768), forKey: AppSettings.Keys.legacyShortcutModifiers)
        userDefaults.set("Legacy prompt", forKey: AppSettings.Keys.legacyPrompt)

        let settings = AppSettings(userDefaults: userDefaults)
        var callbackCount = 0
        settings.onShortcutsChanged = {
            callbackCount += 1
        }

        XCTAssertEqual(settings.apiKeys[.openai], "legacy-key")
        XCTAssertEqual(settings.shortcutActions.first?.keyCode, 12)
        XCTAssertNil(userDefaults.string(forKey: AppSettings.Keys.legacyAPIKey))

        settings.addAction(ShortcutAction(name: "Custom", keyCode: 0, modifiers: 256, prompt: "Prompt"))
        XCTAssertEqual(callbackCount, 1)

        let data = try XCTUnwrap(userDefaults.data(forKey: AppSettings.Keys.shortcutActions))
        let decoded = try JSONDecoder().decode([ShortcutAction].self, from: data)
        XCTAssertEqual(decoded.count, settings.shortcutActions.count)
    }

    func testNoopLaunchController() throws {
        let noop = NoopLaunchAtLoginController()

        XCTAssertFalse(noop.isEnabled)
        XCTAssertNoThrow(try noop.setEnabled(true))
    }

    func testInvalidSavedShortcutDataFallsBackToDefaults() {
        userDefaults.set(Data("invalid".utf8), forKey: AppSettings.Keys.shortcutActions)

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.shortcutActions.map(\.name), ["Translate", "Improve Writing", "Fix Grammar"])
    }

    func testLegacyMigrationKeepsExistingOpenAIKeyAndFallsBackPrompt() {
        userDefaults.set(["openai": "existing"], forKey: AppSettings.Keys.apiKeys)
        userDefaults.set("legacy-key", forKey: AppSettings.Keys.legacyAPIKey)
        userDefaults.set(UInt32(31), forKey: AppSettings.Keys.legacyShortcutKeyCode)
        userDefaults.set(UInt32(768), forKey: AppSettings.Keys.legacyShortcutModifiers)

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.apiKeys[.openai], "existing")
        XCTAssertEqual(settings.shortcutActions.first?.prompt, ShortcutCatalog.templates.first?.prompt)
    }
}
