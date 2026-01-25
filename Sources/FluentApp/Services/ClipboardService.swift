import Cocoa
import ApplicationServices

class ClipboardService {
    static let shared = ClipboardService()
    
    private init() {}
    
    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func copySelectedText() -> String? {
        let originalPasteboard = NSPasteboard.general.string(forType: .string)
        
        // Clear pasteboard to detect change
        NSPasteboard.general.clearContents()
        
        simulateCmdC()
        
        // Wait a bit for the copy to happen
        Thread.sleep(forTimeInterval: 0.1)
        
        // Read from pasteboard
        guard let newText = NSPasteboard.general.string(forType: .string) else {
            // Restore original if copy failed or nothing selected
            if let original = originalPasteboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(original, forType: .string)
            }
            return nil
        }
        
        return newText
    }
    
    func pasteText(_ text: String) {
        let originalPasteboard = NSPasteboard.general.string(forType: .string)
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        simulateCmdV()
        
        // Restore original pasteboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let original = originalPasteboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(original, forType: .string)
            }
        }
    }
    
    private func simulateCmdC() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd
        let cDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)   // C
        let cUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        cDown?.flags = .maskCommand
        cUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        cDown?.post(tap: .cghidEventTap)
        cUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
    
    private func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)
        
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)   // V
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
        
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
