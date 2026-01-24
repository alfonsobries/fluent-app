import Foundation
import Combine

class AppSettings: ObservableObject {
    // MARK: - AI Provider Settings

    @Published var selectedProvider: AIProviderType {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        }
    }

    @Published var apiKeys: [AIProviderType: String] {
        didSet {
            saveAPIKeys()
        }
    }

    @Published var shortcutActions: [ShortcutAction] {
        didSet {
            saveShortcutActions()
        }
    }

    // Callback when shortcuts change (for re-registering hotkeys)
    var onShortcutsChanged: (() -> Void)?

    init() {
        // Load selected provider
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedProvider"),
           let provider = AIProviderType(rawValue: savedProvider) {
            self.selectedProvider = provider
        } else {
            self.selectedProvider = .openai
        }

        // Load API keys
        self.apiKeys = Self.loadAPIKeys()

        // Load shortcut actions
        self.shortcutActions = Self.loadShortcutActions()

        // Migrate old single apiKey if exists
        migrateOldAPIKey()
    }

    // MARK: - Current API Key (convenience)

    /// Get the API key for the currently selected provider
    var currentAPIKey: String {
        apiKeys[selectedProvider] ?? ""
    }

    /// Set the API key for a specific provider
    func setAPIKey(_ key: String, for provider: AIProviderType) {
        apiKeys[provider] = key
    }

    /// Get the current AI provider instance
    var currentProvider: AIProvider {
        AIProviderFactory.shared.resolve(selectedProvider)
    }

    // MARK: - API Keys Persistence

    private func saveAPIKeys() {
        var keysDict: [String: String] = [:]
        for (provider, key) in apiKeys {
            keysDict[provider.rawValue] = key
        }
        UserDefaults.standard.set(keysDict, forKey: "apiKeys")
    }

    private static func loadAPIKeys() -> [AIProviderType: String] {
        guard let keysDict = UserDefaults.standard.dictionary(forKey: "apiKeys") as? [String: String] else {
            return [:]
        }

        var result: [AIProviderType: String] = [:]
        for (key, value) in keysDict {
            if let provider = AIProviderType(rawValue: key) {
                result[provider] = value
            }
        }
        return result
    }

    private func migrateOldAPIKey() {
        // Migrate from old single apiKey format
        if let oldKey = UserDefaults.standard.string(forKey: "apiKey"), !oldKey.isEmpty {
            if apiKeys[.openai]?.isEmpty ?? true {
                apiKeys[.openai] = oldKey
            }
            UserDefaults.standard.removeObject(forKey: "apiKey")
        }
    }

    // MARK: - Shortcut Actions Persistence

    private func saveShortcutActions() {
        if let encoded = try? JSONEncoder().encode(shortcutActions) {
            UserDefaults.standard.set(encoded, forKey: "shortcutActions")
        }
        onShortcutsChanged?()
    }

    private static func loadShortcutActions() -> [ShortcutAction] {
        // Try to load saved actions
        if let data = UserDefaults.standard.data(forKey: "shortcutActions"),
           let actions = try? JSONDecoder().decode([ShortcutAction].self, from: data) {
            return actions
        }

        // Migrate from old single-shortcut format if exists
        if UserDefaults.standard.object(forKey: "shortcutKeyCode") != nil {
            let oldKeyCode = UserDefaults.standard.object(forKey: "shortcutKeyCode") as? UInt32 ?? 31
            let oldModifiers = UserDefaults.standard.object(forKey: "shortcutModifiers") as? UInt32 ?? 768
            let oldPrompt = UserDefaults.standard.string(forKey: "prompt") ??
                "Detect the language of the following text. If it is Spanish, translate it to English. If it is English, translate it to Spanish. Output only the translated text."

            let migratedAction = ShortcutAction(
                name: "Translate",
                keyCode: oldKeyCode,
                modifiers: oldModifiers,
                prompt: oldPrompt
            )

            // Clean up old keys
            UserDefaults.standard.removeObject(forKey: "shortcutKeyCode")
            UserDefaults.standard.removeObject(forKey: "shortcutModifiers")
            UserDefaults.standard.removeObject(forKey: "prompt")

            return [migratedAction]
        }

        // Return defaults
        return ShortcutAction.defaults
    }

    // MARK: - Shortcut Action Management

    func addAction(_ action: ShortcutAction) {
        shortcutActions.append(action)
    }

    func updateAction(_ action: ShortcutAction) {
        if let index = shortcutActions.firstIndex(where: { $0.id == action.id }) {
            shortcutActions[index] = action
        }
    }

    func deleteAction(_ action: ShortcutAction) {
        shortcutActions.removeAll { $0.id == action.id }
    }

    func moveAction(from source: IndexSet, to destination: Int) {
        shortcutActions.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Enabled Actions

    var enabledActions: [ShortcutAction] {
        shortcutActions.filter { $0.isEnabled }
    }

    func actionForHotKey(keyCode: UInt32, modifiers: UInt32) -> ShortcutAction? {
        enabledActions.first { $0.keyCode == keyCode && $0.modifiers == modifiers }
    }
}
