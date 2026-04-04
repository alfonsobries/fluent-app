import FluentCore
import SwiftUI

struct ShortcutEditView: View {
    @ObservedObject var settings: AppSettings
    @Binding var selectedShortcutID: ShortcutAction.ID?

    @State private var draft = ShortcutActionForm()
    @State private var pendingSelectionID: ShortcutAction.ID?
    @State private var showDiscardChangesAlert = false

    private var selectedAction: ShortcutAction? {
        settings.shortcutActions.first { $0.id == selectedShortcutID }
    }

    private var validationMessages: [String] {
        draft.validationMessages(existingActions: settings.shortcutActions, editingID: selectedAction?.id)
    }

    private var hasUnsavedChanges: Bool {
        guard let selectedAction else { return false }
        return draft != ShortcutActionForm(action: selectedAction)
    }

    var body: some View {
        HStack(spacing: 0) {
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

                List(selection: selectionBinding) {
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
                .frame(minWidth: 260, idealWidth: 280, maxWidth: 300)
            }
            .padding(.trailing, 20)

            Divider()

            Group {
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
        }
        .onAppear(perform: syncDraft)
        .onChange(of: selectedShortcutID) { _ in
            syncDraft()
        }
        .alert("You have unsaved changes", isPresented: $showDiscardChangesAlert) {
            Button("Keep Editing", role: .cancel) {
                pendingSelectionID = nil
            }
            Button("Discard Changes") {
                commitPendingSelection()
            }
        } message: {
            Text("Save your shortcut before switching to another action, or discard your edits.")
        }
    }

    private func editor(for action: ShortcutAction) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    if hasUnsavedChanges {
                        Label("You have unsaved changes. Press Save Changes to apply them.", systemImage: "exclamationmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Changes are applied only after you press Save Changes.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button("Delete", role: .destructive) {
                    settings.deleteAction(action)
                    selectedShortcutID = settings.shortcutActions.first?.id
                    syncDraft()
                }

                Button("Discard Changes") {
                    syncDraft()
                }
                .disabled(!hasUnsavedChanges)

                Button("Save Changes") {
                    settings.updateAction(draft.makeAction(existingID: action.id))
                    syncDraft()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasUnsavedChanges || !validationMessages.isEmpty)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)

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
            }
            .formStyle(.grouped)
        }
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

    private var selectionBinding: Binding<ShortcutAction.ID?> {
        Binding(
            get: { selectedShortcutID },
            set: { newValue in
                guard newValue != selectedShortcutID else { return }

                if hasUnsavedChanges {
                    pendingSelectionID = newValue
                    showDiscardChangesAlert = true
                } else {
                    selectedShortcutID = newValue
                }
            }
        )
    }

    private func syncDraft() {
        guard let selectedAction else {
            draft = ShortcutActionForm()
            return
        }

        draft = ShortcutActionForm(action: selectedAction)
    }

    private func commitPendingSelection() {
        selectedShortcutID = pendingSelectionID
        pendingSelectionID = nil
    }
}
