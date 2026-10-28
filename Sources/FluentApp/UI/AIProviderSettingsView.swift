import FluentCore
import SwiftUI

struct AIProviderSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Default Provider") {
                Picker("Provider", selection: Binding(
                    get: { settings.selectedProvider },
                    set: { settings.selectedProvider = $0 }
                )) {
                    ForEach(AIProviderType.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                Text("Fluent App will use this provider when any shortcut is triggered.")
                    .foregroundStyle(.secondary)
            }

            Section("Model") {
                ModelPicker(settings: settings, provider: settings.selectedProvider)
                    .id(settings.selectedProvider)
            }

            Section("API Keys") {
                ForEach(AIProviderType.allCases) { provider in
                    APIKeyRow(provider: provider, apiKey: binding(for: provider), isSelected: settings.selectedProvider == provider)
                }

                if let error = settings.apiKeyStorageError {
                    Label("Couldn’t access the Keychain, so key changes may not be kept after Fluent App quits. \(error)", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Section("Notes") {
                Text("Keys are stored in your macOS Keychain and are only sent to the provider you select.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for provider: AIProviderType) -> Binding<String> {
        Binding(
            get: { settings.apiKeys[provider] ?? "" },
            set: { settings.setAPIKey($0, for: provider) }
        )
    }
}

struct APIKeyRow: View {
    let provider: AIProviderType
    @Binding var apiKey: String
    let isSelected: Bool

    @State private var tempKey = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.displayName)
                            .fontWeight(isSelected ? .semibold : .regular)
                        if isSelected {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    Text(apiKey.isEmpty ? "Not configured" : maskedKey)
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Spacer()

                HStack(spacing: 10) {
                    if let url = URL(string: provider.apiKeyURL) {
                        Link("Get Key", destination: url)
                    }

                    Button(isEditing ? "Cancel" : (apiKey.isEmpty ? "Add Key" : "Edit Key")) {
                        if isEditing {
                            discardDraft()
                        } else {
                            tempKey = apiKey
                            isEditing = true
                        }
                    }
                }
            }

            if isEditing {
                VStack(alignment: .leading, spacing: 12) {
                    Text("API Key")
                        .font(.headline)

                    Text("Paste the complete key exactly as provided by \(provider.displayName). Do not remove the prefix.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    SecureField(fullPlaceholder, text: $tempKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)

                    HStack {
                        if hasChanges {
                            Label("Unsaved changes", systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        Spacer()

                        Button("Cancel") {
                            discardDraft()
                        }

                        Button("Save") {
                            apiKey = tempKey
                            isEditing = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasChanges)
                    }
                }
                .padding(14)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.vertical, 6)
    }

    private var hasChanges: Bool {
        tempKey != apiKey
    }

    private var maskedKey: String {
        guard apiKey.count > 8 else { return "••••••••" }
        return "\(apiKey.prefix(4))••••\(apiKey.suffix(4))"
    }

    private var fullPlaceholder: String {
        switch provider {
        case .openai:
            return "Paste your full key, for example sk-proj-..."
        case .claude:
            return "Paste your full key, for example sk-ant-..."
        case .gemini:
            return "Paste your full key, for example AI..."
        case .grok:
            return "Paste your full key, for example xai-..."
        }
    }

    private func discardDraft() {
        tempKey = apiKey
        isEditing = false
    }
}

struct ModelPicker: View {
    @ObservedObject var settings: AppSettings
    let provider: AIProviderType

    private static let customTag = "__custom__"

    @State private var isCustom = false
    @State private var customModel = ""

    var body: some View {
        Picker("\(provider.displayName) model", selection: selection) {
            ForEach(provider.modelOptions) { option in
                Text(option.name).tag(option.id)
            }
            Divider()
            Text("Custom…").tag(Self.customTag)
        }
        .onAppear(perform: showSavedCustomModel)

        if isCustom {
            HStack {
                TextField("Model ID", text: $customModel, prompt: Text(provider.defaultModel))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(saveCustomModel)
                Button("Save", action: saveCustomModel)
                    .disabled(customModel.trimmingCharacters(in: .whitespacesAndNewlines) == settings.model(for: provider))
            }
            Text("Any model ID from \(provider.displayName). Fluent App sends it as is, so an unknown ID fails when a shortcut runs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let option = selectedOption {
            Text(option.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func showSavedCustomModel() {
        guard selectedOption == nil else { return }
        customModel = settings.model(for: provider)
        isCustom = true
    }

    private var selectedOption: AIModelOption? {
        provider.modelOptions.first { $0.id == settings.model(for: provider) }
    }

    private var selection: Binding<String> {
        Binding(
            get: { isCustom ? Self.customTag : settings.model(for: provider) },
            set: { newValue in
                if newValue == Self.customTag {
                    customModel = settings.model(for: provider)
                    isCustom = true
                } else {
                    isCustom = false
                    settings.setModel(newValue, for: provider)
                }
            }
        )
    }

    private func saveCustomModel() {
        settings.setModel(customModel, for: provider)
        customModel = settings.model(for: provider)
    }
}
