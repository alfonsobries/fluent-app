import Combine
import Foundation

public final class AppSettings: ObservableObject {
    public let objectWillChange = ObservableObjectPublisher()

    public enum Keys {
        public static let selectedProvider = "selectedProvider"
        public static let apiKeys = "apiKeys"
        public static let shortcutActions = "shortcutActions"
        public static let launchAtStartup = "launchAtStartup"
        public static let legacyAPIKey = "apiKey"
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
            saveAPIKeys()
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

    public private(set) var launchAtStartupError: String? {
        didSet {
            objectWillChange.send()
        }
    }

    public var onShortcutsChanged: (() -> Void)?

    private let userDefaults: UserDefaults
    private let launchAtLoginController: LaunchAtLoginControlling
    private let providerFactory: AIProviderFactory

    public init(
        userDefaults: UserDefaults = .standard,
        providerFactory: AIProviderFactory = .live,
        launchAtLoginController: LaunchAtLoginControlling = NoopLaunchAtLoginController()
    ) {
        self.userDefaults = userDefaults
        self.providerFactory = providerFactory
        self.launchAtLoginController = launchAtLoginController

        if
            let rawProvider = userDefaults.string(forKey: Keys.selectedProvider),
            let provider = AIProviderType(rawValue: rawProvider)
        {
            selectedProvider = provider
        } else {
            selectedProvider = .openai
        }

        apiKeys = Self.loadAPIKeys(from: userDefaults)
        shortcutActions = Self.loadShortcutActions(from: userDefaults)

        if userDefaults.object(forKey: Keys.launchAtStartup) != nil {
            launchAtStartup = userDefaults.bool(forKey: Keys.launchAtStartup)
        } else {
            launchAtStartup = true
            userDefaults.set(true, forKey: Keys.launchAtStartup)
        }

        migrateLegacyValues()
        synchronizeLaunchAtStartupPreference()
    }

    public var currentAPIKey: String {
        apiKeys[selectedProvider] ?? ""
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

    private func saveAPIKeys() {
        let rawDictionary = Dictionary(uniqueKeysWithValues: apiKeys.map { ($0.key.rawValue, $0.value) })
        userDefaults.set(rawDictionary, forKey: Keys.apiKeys)
    }

    private func saveShortcutActions() {
        if let data = try? JSONEncoder().encode(shortcutActions) {
            userDefaults.set(data, forKey: Keys.shortcutActions)
        }
        onShortcutsChanged?()
    }

    private static func loadAPIKeys(from userDefaults: UserDefaults) -> [AIProviderType: String] {
        guard let rawDictionary = userDefaults.dictionary(forKey: Keys.apiKeys) as? [String: String] else {
            return [:]
        }

        return rawDictionary.reduce(into: [:]) { partialResult, element in
            if let provider = AIProviderType(rawValue: element.key) {
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
