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

    func testDefaultsLoadAndPersist() throws {
        let store = InMemorySecretStore()
        let settings = AppSettings(userDefaults: userDefaults, secretStore: store)

        XCTAssertEqual(settings.selectedProvider, .openai)
        XCTAssertEqual(settings.shortcutActions.count, 3)
        XCTAssertTrue(settings.launchAtStartup)
        XCTAssertEqual(userDefaults.bool(forKey: AppSettings.Keys.launchAtStartup), true)

        settings.selectedProvider = .claude
        settings.setAPIKey("  abc123  ", for: .claude)

        XCTAssertEqual(userDefaults.string(forKey: AppSettings.Keys.selectedProvider), "claude")
        XCTAssertEqual(try store.secret(for: "claude"), "abc123")
        XCTAssertNil(userDefaults.object(forKey: AppSettings.Keys.legacyAPIKeys))
        XCTAssertEqual(settings.currentAPIKey, "abc123")

        settings.setAPIKey("   ", for: .claude)
        XCTAssertNil(try store.secret(for: "claude"))
        XCTAssertEqual(settings.currentAPIKey, "")
    }

    func testLoadsSavedProviderAPIKeysAndActions() throws {
        userDefaults.set("grok", forKey: AppSettings.Keys.selectedProvider)
        let savedAction = ShortcutAction(name: "Saved", keyCode: 12, modifiers: 256, prompt: "Prompt")
        userDefaults.set(try JSONEncoder().encode([savedAction]), forKey: AppSettings.Keys.shortcutActions)
        userDefaults.set(false, forKey: AppSettings.Keys.launchAtStartup)

        let store = InMemorySecretStore(secrets: ["openai": "one", "grok": "two", "gemini": ""])
        let settings = AppSettings(userDefaults: userDefaults, secretStore: store)

        XCTAssertEqual(settings.selectedProvider, .grok)
        XCTAssertEqual(settings.apiKeys[.openai], "one")
        XCTAssertEqual(settings.apiKeys[.grok], "two")
        XCTAssertNil(settings.apiKeys[.gemini])
        XCTAssertNil(settings.apiKeyStorageError)
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

    func testLaunchAtStartupSynchronizationErrorDuringInitialization() {
        userDefaults.set(true, forKey: AppSettings.Keys.launchAtStartup)
        let controller = MockLaunchAtLoginController(isEnabled: false, error: TestError.failed)

        let settings = AppSettings(userDefaults: userDefaults, launchAtLoginController: controller)

        XCTAssertTrue(settings.launchAtStartup)
        XCTAssertEqual(controller.receivedValues, [true])
        XCTAssertEqual(settings.launchAtStartupError, "boom")
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
        userDefaults.set(["openai": "existing"], forKey: AppSettings.Keys.legacyAPIKeys)
        userDefaults.set("legacy-key", forKey: AppSettings.Keys.legacyAPIKey)
        userDefaults.set(UInt32(31), forKey: AppSettings.Keys.legacyShortcutKeyCode)
        userDefaults.set(UInt32(768), forKey: AppSettings.Keys.legacyShortcutModifiers)

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.apiKeys[.openai], "existing")
        XCTAssertEqual(settings.shortcutActions.first?.prompt, ShortcutCatalog.templates.first?.prompt)
    }

    func testMigratesPlaintextAPIKeysIntoSecretStore() throws {
        userDefaults.set(
            ["openai": "plain-openai", "claude": "plain-claude", "gemini": "", "retired": "x"],
            forKey: AppSettings.Keys.legacyAPIKeys
        )
        let store = InMemorySecretStore(secrets: ["claude": "stored-claude"])

        let settings = AppSettings(userDefaults: userDefaults, secretStore: store)

        XCTAssertEqual(settings.apiKeys[.openai], "plain-openai")
        XCTAssertEqual(settings.apiKeys[.claude], "stored-claude")
        XCTAssertNil(settings.apiKeys[.gemini])
        XCTAssertEqual(try store.secret(for: "openai"), "plain-openai")
        XCTAssertEqual(try store.secret(for: "claude"), "stored-claude")
        XCTAssertNil(userDefaults.object(forKey: AppSettings.Keys.legacyAPIKeys))
        XCTAssertNil(settings.apiKeyStorageError)
    }

    func testMalformedPlaintextAPIKeysAreDiscarded() {
        userDefaults.set("not a dictionary", forKey: AppSettings.Keys.legacyAPIKeys)

        let settings = AppSettings(userDefaults: userDefaults, secretStore: InMemorySecretStore())

        XCTAssertTrue(settings.apiKeys.isEmpty)
        XCTAssertNil(userDefaults.object(forKey: AppSettings.Keys.legacyAPIKeys))
    }

    func testPlaintextAPIKeysAreKeptWhenSecretStoreFails() {
        userDefaults.set(["openai": "plain-openai"], forKey: AppSettings.Keys.legacyAPIKeys)
        let store = FailingSecretStore(failWrites: true)

        let settings = AppSettings(userDefaults: userDefaults, secretStore: store)

        XCTAssertEqual(settings.apiKeys[.openai], "plain-openai")
        XCTAssertEqual(settings.apiKeyStorageError, "boom")
        XCTAssertEqual(
            userDefaults.dictionary(forKey: AppSettings.Keys.legacyAPIKeys) as? [String: String],
            ["openai": "plain-openai"]
        )

        store.failWrites = false
        settings.setAPIKey("fresh", for: .grok)
        XCTAssertNil(settings.apiKeyStorageError)
    }

    func testSecretStoreReadFailureIsReported() {
        let settings = AppSettings(userDefaults: userDefaults, secretStore: FailingSecretStore(failReads: true))

        XCTAssertTrue(settings.apiKeys.isEmpty)
        XCTAssertEqual(settings.apiKeyStorageError, "boom")
    }

    func testUnchangedAPIKeysAreNotRewritten() {
        let store = FailingSecretStore(failWrites: true)
        let settings = AppSettings(userDefaults: userDefaults, secretStore: store)

        let unchanged = settings.apiKeys
        settings.apiKeys = unchanged

        XCTAssertNil(settings.apiKeyStorageError)
    }

    func testModelSelectionPersistsAndFallsBackToDefault() {
        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.currentModel, "gpt-6-luna")
        XCTAssertEqual(settings.model(for: .claude), "claude-haiku-5-5")

        settings.setModel("  claude-opus-5-5 ", for: .claude)
        settings.setModel("my-fine-tune", for: .openai)
        XCTAssertEqual(settings.model(for: .claude), "claude-opus-5-5")
        XCTAssertEqual(settings.currentModel, "my-fine-tune")
        XCTAssertEqual(
            userDefaults.dictionary(forKey: AppSettings.Keys.models) as? [String: String],
            ["claude": "claude-opus-5-5", "openai": "my-fine-tune"]
        )

        let reloaded = AppSettings(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.model(for: .claude), "claude-opus-5-5")

        settings.setModel("", for: .openai)
        settings.setModel("claude-haiku-5-5", for: .claude)
        XCTAssertEqual(settings.currentModel, "gpt-6-luna")
        XCTAssertTrue(settings.models.isEmpty)
    }

    func testInvalidSavedModelsAreIgnored() {
        userDefaults.set(["openai": "", "nope": "x", "grok": "grok-4.3"], forKey: AppSettings.Keys.models)

        let settings = AppSettings(userDefaults: userDefaults)

        XCTAssertEqual(settings.models, [.grok: "grok-4.3"])
        XCTAssertEqual(settings.model(for: .openai), "gpt-6-luna")
    }

    func testEveryProviderOffersItsDefaultModelFirst() {
        for provider in AIProviderType.allCases {
            XCTAssertFalse(provider.modelOptions.isEmpty)
            XCTAssertEqual(provider.defaultModel, provider.modelOptions[0].id)
            XCTAssertEqual(Set(provider.modelOptions.map(\.id)).count, provider.modelOptions.count)
        }
    }
}
