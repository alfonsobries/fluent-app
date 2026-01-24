import SwiftUI
import Carbon

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    @State private var isRecording = false
    @State private var displayText: String = ""
    @State private var eventMonitor: Any?

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
        .onChange(of: keyCode) { _ in updateDisplayText() }
        .onChange(of: modifiers) { _ in updateDisplayText() }
        .onTapGesture {
            startRecording()
        }
        .onDisappear {
            removeEventMonitor()
        }
    }

    private func startRecording() {
        isRecording = true
        displayText = "Press shortcut..."
        // Pause hotkeys while recording
        HotKeyManager.shared.isPaused = true
        installEventMonitor()
    }

    private func stopRecording() {
        isRecording = false
        updateDisplayText()
        HotKeyManager.shared.isPaused = false
        removeEventMonitor()
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil // Consume the event
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard isRecording else { return }

        // Get modifiers
        var newModifiers: UInt32 = 0

        if event.modifierFlags.contains(.command) {
            newModifiers |= UInt32(cmdKey)
        }
        if event.modifierFlags.contains(.shift) {
            newModifiers |= UInt32(shiftKey)
        }
        if event.modifierFlags.contains(.option) {
            newModifiers |= UInt32(optionKey)
        }
        if event.modifierFlags.contains(.control) {
            newModifiers |= UInt32(controlKey)
        }

        // Need at least one modifier
        guard newModifiers != 0 else {
            displayText = "Add Cmd, Shift, Option, or Control"
            return
        }

        // Get key code
        let newKeyCode = UInt32(event.keyCode)

        keyCode = newKeyCode
        modifiers = newModifiers
        stopRecording()
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
}
