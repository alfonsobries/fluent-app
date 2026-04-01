import FluentCore
import SwiftUI

struct ShortcutEditView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedShortcutID: ShortcutAction.ID?

    @State private var draft = ShortcutActionForm()

    private var selectedAction: ShortcutAction? {
        settings.shortcutActions.first { $0.id == selectedShortcutID }
    }

    private var validationMessages: [String] {
        draft.validationMessages(existingActions: settings.shortcutActions, editingID: selectedAction?.id)
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Actions")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("Reset Defaults") {
                        settings.resetToDefaults()
                        selectedShortcutID = settings.shortcutActions.first?.id
                        syncDraft()
                    }
                }

                Menu("New Shortcut") {
                    Button("Blank Shortcut") {
                        let action = ShortcutAction(name: "New Shortcut", keyCode: 0, modifiers: 0, prompt: "")
                        settings.addAction(action)
                        selectedShortcutID = action.id
                        syncDraft()
                    }

                    Divider()

                    ForEach(ShortcutCatalog.templates) { template in
                        Button(template.name) {
                            let action = settings.addAction(from: template)
                            selectedShortcutID = action.id
                            syncDraft()
                        }
                    }
                }

                List(selection: $selectedShortcutID) {
                    ForEach(settings.shortcutActions) { action in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(action.name)
                            Text(action.shortcutDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(action.id)
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: settings.moveAction)
                }
            }
        } detail: {
            if let action = selectedAction {
                editor(for: action)
                    .id(action.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "command")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Select a shortcut")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Choose an existing shortcut or create a new one from a template.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear(perform: syncDraft)
        .onChange(of: selectedShortcutID) { _ in
            syncDraft()
        }
    }

    private func editor(for action: ShortcutAction) -> some View {
        Form {
            Section("Overview") {
                TextField("Name", text: $draft.name)
                Toggle("Enabled", isOn: $draft.isEnabled)
                Text("Shortcut Preview: \(draft.shortcutPreview)")
                    .foregroundStyle(.secondary)
            }

            Section("Keyboard Shortcut") {
                ShortcutRecorderView(keyCode: $draft.keyCode, modifiers: $draft.modifiers)
                Text("Use a modifier combination so the shortcut does not collide with normal typing.")
                    .foregroundStyle(.secondary)
            }

            Section("AI Instructions") {
                TextEditor(text: $draft.prompt)
                    .font(.body)
                    .frame(minHeight: 220)
                Text("The selected text will be sent with these instructions. Keep the output format explicit so replacements paste cleanly.")
                    .foregroundStyle(.secondary)
            }

            if !validationMessages.isEmpty {
                Section("Needs Attention") {
                    ForEach(validationMessages, id: \.self) { message in
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                HStack {
                    Button("Delete", role: .destructive) {
                        settings.deleteAction(action)
                        selectedShortcutID = settings.shortcutActions.first?.id
                        syncDraft()
                    }

                    Spacer()

                    Button("Discard Changes") {
                        syncDraft()
                    }

                    Button("Save Changes") {
                        settings.updateAction(draft.makeAction(existingID: action.id))
                        syncDraft()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!validationMessages.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.leading, 8)
    }

    private func deleteItems(at offsets: IndexSet) {
        let actions = offsets.compactMap { index in
            settings.shortcutActions.indices.contains(index) ? settings.shortcutActions[index] : nil
        }

        actions.forEach(settings.deleteAction)
        selectedShortcutID = settings.shortcutActions.first?.id
        syncDraft()
    }

    private func syncDraft() {
        guard let selectedAction else {
            draft = ShortcutActionForm()
            return
        }

        draft = ShortcutActionForm(action: selectedAction)
    }
}
