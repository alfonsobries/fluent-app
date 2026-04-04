import FluentCore
import Sparkle
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    let updater: SPUUpdater
    @State private var selectedShortcutID: ShortcutAction.ID?

    private var settings: AppSettings { controller.settings }

    var body: some View {
        VStack(spacing: 0) {
            header

            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gearshape") }
                AIProviderSettingsView(settings: settings)
                    .tabItem { Label("Providers", systemImage: "network") }
                ShortcutEditView(settings: settings, selectedShortcutID: $selectedShortcutID)
                    .tabItem { Label("Shortcuts", systemImage: "command") }
            }
            .padding(20)
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 620, idealHeight: 680)
        .onAppear {
            selectedShortcutID = selectedShortcutID ?? settings.shortcutActions.first?.id
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Fluent App")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                Text("AI shortcuts for translation, rewriting, summaries, and any custom text workflow.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                ForEach(settings.enabledActions) { action in
                    Button("\(action.name) (\(action.shortcutDescription))") {
                        controller.processSelection(with: action)
                    }
                }

                Divider()

                Button("Quit Fluent App") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Label("Quick Actions", systemImage: "sparkles")
            }
        }
        .padding(20)
        .background(.bar)
    }

    private var generalTab: some View {
        Form {
            Section("Behavior") {
                Toggle("Launch at login", isOn: Binding(
                    get: { controller.settings.launchAtStartup },
                    set: { controller.settings.launchAtStartup = $0 }
                ))
                Text("Fluent App lives in the menu bar, captures selected text with a shortcut, sends it to your chosen model, and pastes the result back.")
                    .foregroundStyle(.secondary)
            }

            Section("Status") {
                switch controller.state {
                case .idle:
                    Label("Ready", systemImage: "checkmark.circle")
                case .processing(let action):
                    Label("Processing \(action)…", systemImage: "hourglass")
                case .completed(let action):
                    Label("Completed \(action)", systemImage: "checkmark.circle.fill")
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }

                PermissionsStatusView()
            }

            Section("Updates") {
                HStack {
                    Button("Check for Updates…") {
                        updater.checkForUpdates()
                    }

                    Toggle("Check automatically", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                }
            }

            Section("Templates") {
                Text("Use the Shortcuts tab to start from templates for translation, writing improvement, grammar fixes, summaries, or your own prompts.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionsStatusView: View {
    var body: some View {
        HStack {
            Image(systemName: "figure.wave")
            Text("Accessibility access is required so Fluent App can copy the selected text and paste the transformed result.")
            Spacer()
            Button("Open Accessibility Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
