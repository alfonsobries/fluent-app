import Foundation
import SwiftUI

class AppController: ObservableObject {
    static let shared = AppController()
    
    @Published var settings = AppSettings()
    @Published var isProcessing = false
    
    private init() {
        setupHotKey()
    }
    
    func setupHotKey() {
        // Register initial hotkey
        HotKeyManager.shared.registerHotKey(keyCode: settings.shortcutKeyCode, modifiers: settings.shortcutModifiers)
        
        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.processSelection()
        }
    }
    
    func processSelection() {
        guard !isProcessing else { return }
        
        guard ClipboardService.shared.checkAccessibilityPermissions() else {
            print("Permissions missing")
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
        }
        
        // 1. Copy text
        guard let text = ClipboardService.shared.copySelectedText(), !text.isEmpty else {
            DispatchQueue.main.async {
                self.isProcessing = false
            }
            return
        }
        
        // 2. Call API
        OpenAIService.shared.processText(text: text, apiKey: settings.apiKey, instructions: settings.prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result {
                case .success(let responseText):
                    // 3. Paste text
                    ClipboardService.shared.pasteText(responseText)
                case .failure(let error):
                    print("Error: \(error)")
                }
                self.isProcessing = false
            }
        }
    }
}
