import AppKit
import ApplicationServices
import FluentCore

public final class LiveClipboardService: ClipboardServicing {
    public init() {}

    public func checkAccessibilityPermissions(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    public func copySelectedText() -> String? {
        let originalValue = NSPasteboard.general.string(forType: .string)

        NSPasteboard.general.clearContents()
        simulate(keyCode: 0x08)
        Thread.sleep(forTimeInterval: 0.1)

        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            restorePasteboard(with: originalValue)
            return nil
        }

        return copiedText
    }

    public func pasteText(_ text: String) {
        let originalValue = NSPasteboard.general.string(forType: .string)

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        simulate(keyCode: 0x09)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restorePasteboard(with: originalValue)
        }
    }

    private func restorePasteboard(with value: String?) {
        guard let value else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func simulate(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        commandDown?.flags = .maskCommand
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        commandDown?.post(tap: .cghidEventTap)
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        commandUp?.post(tap: .cghidEventTap)
    }
}
