import Foundation

/// Represents a keyboard shortcut with associated AI instructions
struct ShortcutAction: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var keyCode: UInt32
    var modifiers: UInt32
    var prompt: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        keyCode: UInt32,
        modifiers: UInt32,
        prompt: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    /// Human-readable description of the keyboard shortcut
    var shortcutDescription: String {
        var parts: [String] = []

        // Control (4096)
        if modifiers & 4096 != 0 {
            parts.append("Control")
        }
        // Option/Alt (2048)
        if modifiers & 2048 != 0 {
            parts.append("Option")
        }
        // Shift (512)
        if modifiers & 512 != 0 {
            parts.append("Shift")
        }
        // Command (256)
        if modifiers & 256 != 0 {
            parts.append("Cmd")
        }

        // Add the key
        if let keyName = Self.keyCodeToName(keyCode) {
            parts.append(keyName)
        } else {
            parts.append("Key(\(keyCode))")
        }

        return parts.joined(separator: "+")
    }

    /// Maps common key codes to readable names
    static func keyCodeToName(_ code: UInt32) -> String? {
        let keyNames: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
            45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`",
            51: "Delete", 53: "Escape", 96: "F5", 97: "F6", 98: "F7",
            99: "F3", 100: "F8", 101: "F9", 109: "F10", 111: "F12",
            118: "F4", 119: "F5", 120: "F6", 121: "F8", 122: "F1",
            123: "Left", 124: "Right", 125: "Down", 126: "Up"
        ]
        return keyNames[code]
    }

    /// Default shortcut actions
    static var defaults: [ShortcutAction] {
        [
            ShortcutAction(
                name: "Translate",
                keyCode: 31, // O
                modifiers: 768, // Cmd+Shift
                prompt: "Detect the language of the following text. If it is Spanish, translate it to English. If it is English, translate it to Spanish. Output only the translated text without any explanations."
            ),
            ShortcutAction(
                name: "Improve Writing",
                keyCode: 34, // I
                modifiers: 768, // Cmd+Shift
                prompt: "Improve the writing of the following text. Fix grammar, improve clarity, and make it more professional. Keep the same language. Output only the improved text without explanations."
            ),
            ShortcutAction(
                name: "Fix Grammar",
                keyCode: 5, // G
                modifiers: 768, // Cmd+Shift
                prompt: "Fix the grammar and spelling of the following text. Keep the same language and style. Output only the corrected text.",
                isEnabled: false
            )
        ]
    }
}
