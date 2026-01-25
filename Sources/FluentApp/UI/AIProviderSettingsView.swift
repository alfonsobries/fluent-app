import SwiftUI

struct AIProviderSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var showingAPIKeyFor: AIProviderType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Provider Selection
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Provider")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Provider", selection: $settings.selectedProvider) {
                    ForEach(AIProviderType.allCases, id: \.self) { provider in
                        HStack {
                            Text(provider.displayName)
                            if hasAPIKey(for: provider) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        .tag(provider)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // API Keys Section
            VStack(alignment: .leading, spacing: 8) {
                Text("API Keys")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ForEach(AIProviderType.allCases, id: \.self) { provider in
                    APIKeyRow(
                        provider: provider,
                        apiKey: binding(for: provider),
                        isSelected: settings.selectedProvider == provider
                    )
                }
            }

            // Current provider info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Using: \(settings.selectedProvider.displayName)")
                    .font(.caption)
                Spacer()
                if let url = URL(string: settings.selectedProvider.apiKeyURL) {
                    Link("Get API Key", destination: url)
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
    }

    private func hasAPIKey(for provider: AIProviderType) -> Bool {
        guard let key = settings.apiKeys[provider] else { return false }
        return !key.isEmpty
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

    @State private var isEditing = false
    @State private var tempKey = ""

    var body: some View {
        HStack {
            // Provider indicator
            Circle()
                .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            // Provider name
            Text(provider.displayName)
                .font(.caption)
                .frame(width: 120, alignment: .leading)
                .foregroundColor(isSelected ? .primary : .secondary)

            // API Key field or status
            if isEditing {
                SecureField(provider.apiKeyPlaceholder, text: $tempKey)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: .infinity)

                Button("Save") {
                    apiKey = tempKey
                    isEditing = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Cancel") {
                    isEditing = false
                    tempKey = apiKey
                }
                .controlSize(.small)
            } else {
                HStack {
                    if apiKey.isEmpty {
                        Text("Not configured")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(maskedKey)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(apiKey.isEmpty ? "Add" : "Edit") {
                        tempKey = apiKey
                        isEditing = true
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }

    private var maskedKey: String {
        guard apiKey.count > 8 else { return "••••••••" }
        let prefix = String(apiKey.prefix(4))
        let suffix = String(apiKey.suffix(4))
        return "\(prefix)••••\(suffix)"
    }
}
