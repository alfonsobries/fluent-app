import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
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
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.shortcutActions = Self.loadShortcutActions()
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
