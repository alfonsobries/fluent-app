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

            Section("API Keys") {
                ForEach(AIProviderType.allCases) { provider in
                    APIKeyRow(provider: provider, apiKey: binding(for: provider), isSelected: settings.selectedProvider == provider)
                }
            }

            Section("Notes") {
                Text("Keys are stored locally in user defaults on this Mac. For open source distribution, document your own preferred storage strategy if you later migrate to Keychain.")
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
