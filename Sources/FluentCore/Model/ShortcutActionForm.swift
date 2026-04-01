import Foundation

public struct ShortcutActionForm: Equatable {
    public var name: String
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var prompt: String
    public var isEnabled: Bool

    public init(
        name: String = "",
        keyCode: UInt32 = 0,
        modifiers: UInt32 = 0,
        prompt: String = "",
        isEnabled: Bool = true
    ) {
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    public init(action: ShortcutAction) {
        self.init(
            name: action.name,
            keyCode: action.keyCode,
            modifiers: action.modifiers,
            prompt: action.prompt,
            isEnabled: action.isEnabled
        )
    }

    public var shortcutPreview: String {
        guard modifiers != 0 || keyCode != 0 else {
            return "Not set"
        }

        return ShortcutAction(
            name: name,
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: prompt,
            isEnabled: isEnabled
        ).shortcutDescription
    }

    public func validationMessages(existingActions: [ShortcutAction], editingID: UUID?) -> [String] {
        var messages: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Name is required.")
        }

        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Instructions are required.")
        }

        if modifiers == 0 {
            messages.append("Shortcut modifiers are required.")
        }

        let candidate = ShortcutAction(
            id: editingID ?? UUID(),
            name: name,
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: prompt,
            isEnabled: isEnabled
        )

        if existingActions.contains(where: { $0.id != editingID && $0.usesSameShortcut(as: candidate) }) {
            messages.append("That keyboard shortcut is already in use.")
        }

        return messages
    }

    public func makeAction(existingID: UUID? = nil) -> ShortcutAction {
        ShortcutAction(
            id: existingID ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines),
            isEnabled: isEnabled
        )
    }
}
