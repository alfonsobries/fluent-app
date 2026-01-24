import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedAction: ShortcutAction?
    @State private var showingAddSheet = false
    @State private var newAction = ShortcutAction(
        name: "",
        keyCode: 0,
        modifiers: 768,
        prompt: ""
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("TranslateTool")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }

            Divider()

            // General Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("General")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Launch at startup", isOn: $settings.launchAtStartup)
                    .toggleStyle(.checkbox)
            }

            Divider()

            // AI Provider Settings
            AIProviderSettingsView(settings: settings)

            Divider()

            // Shortcuts List
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Shortcut Actions")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: { addNewAction() }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                }

                if settings.shortcutActions.isEmpty {
                    Text("No shortcuts configured. Click + to add one.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(settings.shortcutActions) { action in
                                ShortcutRowView(
                                    action: action,
                                    onToggle: { toggleAction(action) },
                                    onEdit: { selectedAction = action }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }

            Divider()

            // Permissions Status
            PermissionsStatusView()

            // Version
            HStack {
                Spacer()
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 420)
        .sheet(item: $selectedAction) { action in
            ShortcutEditSheet(
                action: action,
                settings: settings
            )
        }
        .sheet(isPresented: $showingAddSheet) {
            ShortcutEditView(
                action: $newAction,
                isNew: true
            )
            .onDisappear {
                if !newAction.name.isEmpty && !newAction.prompt.isEmpty {
                    settings.addAction(newAction)
                }
                // Reset for next time
                newAction = ShortcutAction(
                    name: "",
                    keyCode: 0,
                    modifiers: 768,
                    prompt: ""
                )
            }
        }
    }

    private func addNewAction() {
        showingAddSheet = true
    }

    private func toggleAction(_ action: ShortcutAction) {
        var updated = action
        updated.isEnabled.toggle()
        settings.updateAction(updated)
    }
}

// MARK: - Shortcut Row

struct ShortcutRowView: View {
    let action: ShortcutAction
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { action.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text(action.name)
                    .font(.body)
                    .foregroundColor(action.isEnabled ? .primary : .secondary)
                Text(action.shortcutDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Edit Sheet Wrapper

struct ShortcutEditSheet: View {
    let action: ShortcutAction
    let settings: AppSettings

    @State private var editableAction: ShortcutAction

    init(action: ShortcutAction, settings: AppSettings) {
        self.action = action
        self.settings = settings
        self._editableAction = State(initialValue: action)
    }

    var body: some View {
        ShortcutEditView(
            action: $editableAction,
            onDelete: {
                settings.deleteAction(action)
            }
        )
        .onDisappear {
            if editableAction != action {
                settings.updateAction(editableAction)
            }
        }
    }
}

// MARK: - Permissions Status

struct PermissionsStatusView: View {
    var body: some View {
        HStack {
            if ClipboardService.shared.checkAccessibilityPermissions() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Accessibility Permissions Granted")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                Text("Accessibility Permissions Needed")
                Spacer()
                Button("Open Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .font(.caption)
    }
}
