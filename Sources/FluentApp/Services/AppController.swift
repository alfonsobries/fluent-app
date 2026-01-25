import Foundation
import SwiftUI

class AppController: ObservableObject {
    static let shared = AppController()

    @Published var settings = AppSettings()
    @Published var isProcessing = false
    @Published var currentActionName: String?

    private init() {
        setupHotKeys()

        // Re-register hotkeys when settings change
        settings.onShortcutsChanged = { [weak self] in
            self?.setupHotKeys()
        }
    }

    func setupHotKeys() {
        HotKeyManager.shared.registerHotKeys(for: settings.enabledActions)

        HotKeyManager.shared.onTrigger = { [weak self] action in
            self?.processSelection(with: action)
        }
    }

    func processSelection(with action: ShortcutAction) {
        guard !isProcessing else { return }

        guard ClipboardService.shared.checkAccessibilityPermissions() else {
            print("Permissions missing")
            return
        }

        // Check if API key is configured
        guard !settings.currentAPIKey.isEmpty else {
            print("API key not configured for \(settings.selectedProvider.displayName)")
            return
        }

        DispatchQueue.main.async {
            self.isProcessing = true
            self.currentActionName = action.name
        }

        // 1. Copy selected text
        guard let text = ClipboardService.shared.copySelectedText(), !text.isEmpty else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.currentActionName = nil
            }
            return
        }

        // 2. Get the current AI provider and process
        let provider = settings.currentProvider
        let apiKey = settings.currentAPIKey

        provider.processText(
            text: text,
            apiKey: apiKey,
            instructions: action.prompt
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let responseText):
                    // 3. Paste the result
                    ClipboardService.shared.pasteText(responseText)
                case .failure(let error):
                    print("Error processing '\(action.name)': \(error.localizedDescription)")
                }
                self.isProcessing = false
                self.currentActionName = nil
            }
        }
    }
}
