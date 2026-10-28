import Combine
import Foundation

public final class AppSettings: ObservableObject {
    public let objectWillChange = ObservableObjectPublisher()

    public enum Keys {
        public static let selectedProvider = "selectedProvider"
        public static let shortcutActions = "shortcutActions"
        public static let models = "models"
        public static let launchAtStartup = "launchAtStartup"
        public static let legacyAPIKey = "apiKey"
        /// Plain-text `[provider: key]` dictionary used before keys moved to the secret store.
        public static let legacyAPIKeys = "apiKeys"
        public static let legacyShortcutKeyCode = "shortcutKeyCode"
        public static let legacyShortcutModifiers = "shortcutModifiers"
        public static let legacyPrompt = "prompt"
    }

    public var selectedProvider: AIProviderType {
        didSet {
            objectWillChange.send()
            userDefaults.set(selectedProvider.rawValue, forKey: Keys.selectedProvider)
        }
    }

    public var apiKeys: [AIProviderType: String] {
        didSet {
            objectWillChange.send()
            saveAPIKeys(previous: oldValue)
        }
    }

    /// Model chosen per provider. A provider without an entry uses its default model.
    public var models: [AIProviderType: String] {
        didSet {
            objectWillChange.send()
            let rawDictionary = Dictionary(uniqueKeysWithValues: models.map { ($0.key.rawValue, $0.value) })
            userDefaults.set(rawDictionary, forKey: Keys.models)
        }
    }

    public var shortcutActions: [ShortcutAction] {
        didSet {
            objectWillChange.send()
            saveShortcutActions()
        }
    }

    public var launchAtStartup: Bool {
        didSet {
            objectWillChange.send()
            userDefaults.set(launchAtStartup, forKey: Keys.launchAtStartup)
            do {
                try launchAtLoginController.setEnabled(launchAtStartup)
            } catch {
                launchAtStartupError = error.localizedDescription
            }
        }
    }

    public private(set) var apiKeyStorageError: String? {
        didSet {
            objectWillChange.send()
        }
    }

    public private(set) var launchAtStartupError: String? {
        didSet {
            objectWillChange.send()
        }
    }

    public var onShortcutsChanged: (() -> Void)?

    private let userDefaults: UserDefaults
    private let launchAtLoginController: LaunchAtLoginControlling
    private let providerFactory: AIProviderFactory
    private let secretStore: SecretStoring

    public init(
        userDefaults: UserDefaults = .standard,
        providerFactory: AIProviderFactory = .live,
        launchAtLoginController: LaunchAtLoginControlling = NoopLaunchAtLoginController(),
        secretStore: SecretStoring = InMemorySecretStore()
    ) {
        self.userDefaults = userDefaults
        self.providerFactory = providerFactory
        self.launchAtLoginController = launchAtLoginController
        self.secretStore = secretStore

        if
            let rawProvider = userDefaults.string(forKey: Keys.selectedProvider),
            let provider = AIProviderType(rawValue: rawProvider)
        {
            selectedProvider = provider
        } else {
            selectedProvider = .openai
        }

        var loadError: String?
        apiKeys = Self.loadAPIKeys(from: secretStore, error: &loadError)
        apiKeyStorageError = loadError
        models = Self.loadModels(from: userDefaults)
        shortcutActions = Self.loadShortcutActions(from: userDefaults)

        if userDefaults.object(forKey: Keys.launchAtStartup) != nil {
            launchAtStartup = userDefaults.bool(forKey: Keys.launchAtStartup)
        } else {
            launchAtStartup = true
            userDefaults.set(true, forKey: Keys.launchAtStartup)
        }

        migratePlaintextAPIKeys()
        migrateLegacyValues()
        synchronizeLaunchAtStartupPreference()
    }

    public var currentAPIKey: String {
        apiKeys[selectedProvider] ?? ""
    }

    public var currentModel: String {
        model(for: selectedProvider)
    }

    public func model(for provider: AIProviderType) -> String {
        models[provider] ?? provider.defaultModel
    }

    /// Stores a model ID for the provider; a blank value or the default model clears the
    /// override so the provider keeps following future default updates.
    public func setModel(_ model: String, for provider: AIProviderType) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        models[provider] = trimmed.isEmpty || trimmed == provider.defaultModel ? nil : trimmed
    }

    public var currentProvider: AIProvider {
        providerFactory.resolve(selectedProvider)
    }

    public var enabledActions: [ShortcutAction] {
        shortcutActions.filter(\.isEnabled)
    }

    public var isLaunchAtStartupEnabled: Bool {
        launchAtLoginController.isEnabled
    }

    public func setAPIKey(_ key: String, for provider: AIProviderType) {
        apiKeys[provider] = key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func addAction(_ action: ShortcutAction) {
        shortcutActions.append(action)
    }

    public func addAction(from template: ShortcutTemplate) -> ShortcutAction {
        let action = template.makeAction()
        addAction(action)
        return action
    }

    public func updateAction(_ action: ShortcutAction) {
        guard let index = shortcutActions.firstIndex(where: { $0.id == action.id }) else {
            return
        }

        shortcutActions[index] = action
    }

    public func deleteAction(_ action: ShortcutAction) {
        shortcutActions.removeAll { $0.id == action.id }
    }

    public func moveAction(from source: IndexSet, to destination: Int) {
        let items = source.map { shortcutActions[$0] }
        shortcutActions = shortcutActions.enumerated().filter { !source.contains($0.offset) }.map(\.element)

        let targetIndex = min(destination, shortcutActions.count)
        shortcutActions.insert(contentsOf: items, at: targetIndex)
    }

    public func resetToDefaults() {
        shortcutActions = ShortcutCatalog.defaults
    }

    public func actionForHotKey(keyCode: UInt32, modifiers: UInt32) -> ShortcutAction? {
        enabledActions.first { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }

    private func saveAPIKeys(previous: [AIProviderType: String]) {
        let changed = AIProviderType.allCases.filter { (apiKeys[$0] ?? "") != (previous[$0] ?? "") }
        guard !changed.isEmpty else { return }

        do {
            for provider in changed {
                if let key = apiKeys[provider], !key.isEmpty {
                    try secretStore.setSecret(key, for: provider.rawValue)
                } else {
                    try secretStore.removeSecret(for: provider.rawValue)
                }
            }
            apiKeyStorageError = nil
        } catch {
            apiKeyStorageError = error.localizedDescription
        }
    }

    private func saveShortcutActions() {
        if let data = try? JSONEncoder().encode(shortcutActions) {
            userDefaults.set(data, forKey: Keys.shortcutActions)
        }
        onShortcutsChanged?()
    }

    private static func loadAPIKeys(from secretStore: SecretStoring, error: inout String?) -> [AIProviderType: String] {
        AIProviderType.allCases.reduce(into: [:]) { partialResult, provider in
            do {
                if let key = try secretStore.secret(for: provider.rawValue), !key.isEmpty {
                    partialResult[provider] = key
                }
            } catch let readError {
                error = readError.localizedDescription
            }
        }
    }

    private static func loadModels(from userDefaults: UserDefaults) -> [AIProviderType: String] {
        let rawDictionary = userDefaults.dictionary(forKey: Keys.models) as? [String: String] ?? [:]
        return rawDictionary.reduce(into: [:]) { partialResult, element in
            if let provider = AIProviderType(rawValue: element.key), !element.value.isEmpty {
                partialResult[provider] = element.value
            }
        }
    }

    private static func loadShortcutActions(from userDefaults: UserDefaults) -> [ShortcutAction] {
        if
            let data = userDefaults.data(forKey: Keys.shortcutActions),
            let decoded = try? JSONDecoder().decode([ShortcutAction].self, from: data)
        {
            return decoded
        }

        if userDefaults.object(forKey: Keys.legacyShortcutKeyCode) != nil {
            let keyCode = userDefaults.object(forKey: Keys.legacyShortcutKeyCode) as? UInt32 ?? 31
            let modifiers = userDefaults.object(forKey: Keys.legacyShortcutModifiers) as? UInt32 ?? 768
            let prompt = userDefaults.string(forKey: Keys.legacyPrompt)
                ?? ShortcutCatalog.templates.first!.prompt

            return [
                ShortcutAction(
                    name: "Translate",
                    keyCode: keyCode,
                    modifiers: modifiers,
                    prompt: prompt
                )
            ]
        }

        return ShortcutCatalog.defaults
    }

    /// Moves keys saved in plain text by older versions into the secret store. The
    /// plain-text copy is only removed once every key is stored, so a failing
    /// store never loses a key.
    private func migratePlaintextAPIKeys() {
        guard let rawDictionary = userDefaults.dictionary(forKey: Keys.legacyAPIKeys) as? [String: String] else {
            userDefaults.removeObject(forKey: Keys.legacyAPIKeys)
            return
        }

        var merged = apiKeys
        for (rawProvider, key) in rawDictionary where !key.isEmpty {
            if let provider = AIProviderType(rawValue: rawProvider), merged[provider]?.isEmpty ?? true {
                merged[provider] = key
            }
        }
        apiKeys = merged

        if apiKeyStorageError == nil {
            userDefaults.removeObject(forKey: Keys.legacyAPIKeys)
        }
    }

    private func migrateLegacyValues() {
        if let legacyKey = userDefaults.string(forKey: Keys.legacyAPIKey), !legacyKey.isEmpty {
            if apiKeys[.openai]?.isEmpty ?? true {
                apiKeys[.openai] = legacyKey
            }
            userDefaults.removeObject(forKey: Keys.legacyAPIKey)
        }

        if userDefaults.object(forKey: Keys.legacyShortcutKeyCode) != nil {
            userDefaults.removeObject(forKey: Keys.legacyShortcutKeyCode)
            userDefaults.removeObject(forKey: Keys.legacyShortcutModifiers)
            userDefaults.removeObject(forKey: Keys.legacyPrompt)
            saveShortcutActions()
        }
    }

    private func synchronizeLaunchAtStartupPreference() {
        guard launchAtLoginController.isEnabled != launchAtStartup else { return }

        do {
            try launchAtLoginController.setEnabled(launchAtStartup)
            launchAtStartupError = nil
        } catch {
            launchAtStartupError = error.localizedDescription
        }
    }
}
