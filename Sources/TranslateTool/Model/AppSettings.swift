import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var apiKey: String {
        didSet {
            UserDefaults.standard.set(apiKey, forKey: "apiKey")
        }
    }
    
    @Published var prompt: String {
        didSet {
            UserDefaults.standard.set(prompt, forKey: "prompt")
        }
    }
    
    @Published var shortcutKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(shortcutKeyCode, forKey: "shortcutKeyCode")
        }
    }
    
    @Published var shortcutModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(shortcutModifiers, forKey: "shortcutModifiers")
        }
    }
    
    init() {
        self.apiKey = UserDefaults.standard.string(forKey: "apiKey") ?? ""
        self.prompt = UserDefaults.standard.string(forKey: "prompt") ?? "Detect the language of the following text. If it is Spanish, translate it to English. If it is English, correct the grammar and improve the style. Output only the result."
        
        // Default: Cmd+Shift+O (31)
        // Cmd (256) + Shift (512) = 768
        let savedKeyCode = UserDefaults.standard.object(forKey: "shortcutKeyCode") as? UInt32
        let savedModifiers = UserDefaults.standard.object(forKey: "shortcutModifiers") as? UInt32
        
        self.shortcutKeyCode = savedKeyCode ?? 31 // O
        self.shortcutModifiers = savedModifiers ?? 768 // Cmd+Shift
    }
}
