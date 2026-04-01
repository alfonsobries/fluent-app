import Carbon
import FluentCore
import SwiftUI

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32

    @State private var isRecording = false
    @State private var displayText = "Not set"
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                HStack {
                    Image(systemName: isRecording ? "record.circle.fill" : "keyboard")
                    Text(displayText)
                        .frame(minWidth: 180, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)

            if isRecording {
                Text("Press the full shortcut now")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: updateDisplayText)
        .onChange(of: keyCode) { _ in updateDisplayText() }
        .onChange(of: modifiers) { _ in updateDisplayText() }
        .onDisappear(perform: removeEventMonitor)
    }

    private func startRecording() {
        isRecording = true
        displayText = "Press shortcut..."
        installEventMonitor()
    }

    private func stopRecording() {
        isRecording = false
        updateDisplayText()
        removeEventMonitor()
    }

    private func installEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard isRecording else { return event }
            handle(event)
            return nil
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        var recordedModifiers: UInt32 = 0

        if event.modifierFlags.contains(.command) { recordedModifiers |= UInt32(cmdKey) }
        if event.modifierFlags.contains(.shift) { recordedModifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.option) { recordedModifiers |= UInt32(optionKey) }
        if event.modifierFlags.contains(.control) { recordedModifiers |= UInt32(controlKey) }

        guard recordedModifiers != 0 else {
            displayText = "Use Cmd, Shift, Option, or Control"
            return
        }

        keyCode = UInt32(event.keyCode)
        modifiers = recordedModifiers
        stopRecording()
    }

    private func updateDisplayText() {
        guard modifiers != 0 || keyCode != 0 else {
            displayText = "Not set"
            return
        }

        displayText = ShortcutAction(name: "", keyCode: keyCode, modifiers: modifiers, prompt: "").shortcutDescription
    }
}
