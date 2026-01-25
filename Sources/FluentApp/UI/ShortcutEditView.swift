import SwiftUI

struct ShortcutEditView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var action: ShortcutAction
    var onDelete: (() -> Void)?
    var isNew: Bool = false

    @State private var name: String = ""
    @State private var keyCode: UInt32 = 0
    @State private var modifiers: UInt32 = 0
    @State private var prompt: String = ""
    @State private var isEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isNew ? "New Shortcut Action" : "Edit Shortcut Action")
                .font(.headline)

            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("e.g., Translate, Improve Writing", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }

            // Shortcut
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcut")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                ShortcutRecorderView(keyCode: $keyCode, modifiers: $modifiers)
            }

            // Instructions
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Instructions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextEditor(text: $prompt)
                    .frame(height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                Text("These instructions tell the AI how to process the selected text.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Enabled toggle
            Toggle("Enabled", isOn: $isEnabled)

            Divider()

            // Actions
            HStack {
                if !isNew, let onDelete = onDelete {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    saveAction()
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty || prompt.isEmpty || modifiers == 0)
            }
        }
        .padding()
        .frame(width: 450, height: 420)
        .onAppear {
            name = action.name
            keyCode = action.keyCode
            modifiers = action.modifiers
            prompt = action.prompt
            isEnabled = action.isEnabled
        }
    }

    private func saveAction() {
        action.name = name
        action.keyCode = keyCode
        action.modifiers = modifiers
        action.prompt = prompt
        action.isEnabled = isEnabled
    }
}
