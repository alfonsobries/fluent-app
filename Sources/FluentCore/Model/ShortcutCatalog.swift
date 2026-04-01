import Foundation

public struct ShortcutTemplate: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let keyCode: UInt32
    public let modifiers: UInt32
    public let prompt: String
    public let isEnabled: Bool

    public init(id: String, name: String, keyCode: UInt32, modifiers: UInt32, prompt: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    public func makeAction() -> ShortcutAction {
        ShortcutAction(
            name: name,
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: prompt,
            isEnabled: isEnabled
        )
    }
}

public enum ShortcutCatalog {
    public static let templates: [ShortcutTemplate] = [
        ShortcutTemplate(
            id: "translate",
            name: "Translate",
            keyCode: 31,
            modifiers: 768,
            prompt: "Detect the language of the following text. If it is Spanish, translate it to English. If it is English, translate it to Spanish. Output only the translated text without any explanations."
        ),
        ShortcutTemplate(
            id: "improve",
            name: "Improve Writing",
            keyCode: 34,
            modifiers: 768,
            prompt: "Improve the writing of the following text. Fix grammar, improve clarity, and make it more professional. Keep the same language. Output only the improved text without explanations."
        ),
        ShortcutTemplate(
            id: "grammar",
            name: "Fix Grammar",
            keyCode: 5,
            modifiers: 768,
            prompt: "Fix the grammar and spelling of the following text. Keep the same language and style. Output only the corrected text.",
            isEnabled: false
        ),
        ShortcutTemplate(
            id: "summarize",
            name: "Summarize",
            keyCode: 1,
            modifiers: 768,
            prompt: "Summarize the following text in 3 concise bullet points. Keep the same language as the input."
        ),
        ShortcutTemplate(
            id: "tone",
            name: "Make Professional",
            keyCode: 35,
            modifiers: 768,
            prompt: "Rewrite the following text in a polished professional tone. Preserve the meaning and keep the same language."
        )
    ]

    public static var defaults: [ShortcutAction] {
        Array(templates.prefix(3)).map { $0.makeAction() }
    }
}
