import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    @State private var isRecording = false
    @State private var displayText: String = ""

    var body: some View {
        HStack {
            Text(displayText.isEmpty ? "Click to record" : displayText)
                .frame(minWidth: 120, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )

            if isRecording {
                Button("Cancel") {
                    stopRecording()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .onAppear {
            updateDisplayText()
        }
        .onChange(of: keyCode) { _, _ in updateDisplayText() }
        .onChange(of: modifiers) { _, _ in updateDisplayText() }
        .focusable()
        .onKeyPress { keyPress in
            if isRecording {
                handleKeyPress(keyPress)
                return .handled
            }
            return .ignored
        }
        .onTapGesture {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        displayText = "Press shortcut..."
        // Pause hotkeys while recording
        HotKeyManager.shared.isPaused = true
    }

    private func stopRecording() {
        isRecording = false
        updateDisplayText()
        HotKeyManager.shared.isPaused = false
    }

    private func handleKeyPress(_ keyPress: KeyPress) {
        // Get modifiers from the key press
        var newModifiers: UInt32 = 0

        if keyPress.modifiers.contains(.command) {
            newModifiers |= 256 // cmdKey
        }
        if keyPress.modifiers.contains(.shift) {
            newModifiers |= 512 // shiftKey
        }
        if keyPress.modifiers.contains(.option) {
            newModifiers |= 2048 // optionKey
        }
        if keyPress.modifiers.contains(.control) {
            newModifiers |= 4096 // controlKey
        }

        // Need at least one modifier
        guard newModifiers != 0 else {
            displayText = "Add Cmd, Shift, Option, or Control"
            return
        }

        // Get key code from character
        if let newKeyCode = keyCodeFromCharacter(keyPress.characters) {
            keyCode = newKeyCode
            modifiers = newModifiers
            stopRecording()
        }
    }

    private func updateDisplayText() {
        if let action = createTemporaryAction() {
            displayText = action.shortcutDescription
        } else {
            displayText = "Not set"
        }
    }

    private func createTemporaryAction() -> ShortcutAction? {
        guard keyCode != 0 || modifiers != 0 else { return nil }
        return ShortcutAction(
            name: "",
            keyCode: keyCode,
            modifiers: modifiers,
            prompt: ""
        )
    }

    private func keyCodeFromCharacter(_ char: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, " ": 49, "`": 50
        ]
        return keyMap[char.lowercased()]
    }
}
