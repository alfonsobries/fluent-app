import Carbon
import Cocoa

class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var registeredActions: [UInt32: ShortcutAction] = [:]

    @Published var isPaused = false

    // Called when a hotkey is triggered, passes the action
    var onTrigger: ((ShortcutAction) -> Void)?

    private init() {}

    /// Register multiple hotkeys from shortcut actions
    func registerHotKeys(for actions: [ShortcutAction]) {
        unregisterAllHotKeys()

        for (index, action) in actions.enumerated() where action.isEnabled {
            registerSingleHotKey(action: action, id: UInt32(index + 1))
        }

        if !hotKeyRefs.isEmpty {
            installEventHandler()
        }
    }

    private func registerSingleHotKey(action: ShortcutAction, id: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(String("htk\(id)".prefix(4)).asUInt32)
        hotKeyID.id = id

        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            action.keyCode,
            action.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs[id] = ref
            registeredActions[id] = action
            print("HotKey registered: \(action.name) (\(action.shortcutDescription))")
        } else {
            print("Failed to register hotkey '\(action.name)': \(status)")
        }
    }

    func unregisterAllHotKeys() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        registeredActions.removeAll()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handler: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if status == noErr {
                DispatchQueue.main.async {
                    let manager = HotKeyManager.shared
                    if !manager.isPaused,
                       let action = manager.registeredActions[hotKeyID.id] {
                        manager.onTrigger?(action)
                    }
                }
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &eventHandler
        )
    }
}

extension String {
    var asUInt32: UInt32 {
        var result: UInt32 = 0
        for char in self.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}
