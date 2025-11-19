import Carbon
import Cocoa

class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // Default: Cmd+Shift+O (O for OpenAI/Option)
    // Modifiers: cmdKey + shiftKey
    // KeyCode: 31 (O)
    @Published var isPaused = false
    
    var onTrigger: (() -> Void)?
    
    private init() {}
    
    func registerHotKey(keyCode: UInt32, modifiers: UInt32) {
        unregisterHotKey()
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("htk1".asUInt32)
        hotKeyID.id = 1
        
        let status = RegisterEventHotKey(keyCode,
                                         modifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status == noErr {
            installEventHandler()
            print("HotKey registered successfully.")
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }
    
    func unregisterHotKey() {
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        
        let handler: EventHandlerUPP = { _, _, _ in
            DispatchQueue.main.async {
                if !HotKeyManager.shared.isPaused {
                    HotKeyManager.shared.onTrigger?()
                }
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(),
                            handler,
                            1,
                            &eventType,
                            nil,
                            &eventHandler)
    }
}

extension String {
    var asUInt32: UInt32 {
        var result: UInt32 = 0
        for char in self.utf8 {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}
