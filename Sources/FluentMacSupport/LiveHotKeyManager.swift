import Carbon
import Cocoa
import FluentCore

public final class LiveHotKeyManager: ObservableObject, HotKeyManaging {
    public static let shared = LiveHotKeyManager()

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var registeredActions: [UInt32: ShortcutAction] = [:]

    @Published public var isPaused = false
    public var onTrigger: ((ShortcutAction) -> Void)?

    public init() {}

    public func registerHotKeys(for actions: [ShortcutAction]) {
        unregisterAllHotKeys()

        for (index, action) in actions.enumerated() where action.isEnabled {
            registerSingleHotKey(action: action, id: UInt32(index + 1))
        }

        if !hotKeyRefs.isEmpty {
            installEventHandler()
        }
    }

    public func unregisterAllHotKeys() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }

        hotKeyRefs.removeAll()
        registeredActions.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func registerSingleHotKey(action: ShortcutAction, id: UInt32) {
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType("htk\(id)".fourCharCodeValue)
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

        guard status == noErr, let hotKeyRef else { return }
        hotKeyRefs[id] = hotKeyRef
        registeredActions[id] = action
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, _ in
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

            guard status == noErr else { return noErr }

            DispatchQueue.main.async {
                let manager = LiveHotKeyManager.shared
                guard !manager.isPaused, let action = manager.registeredActions[hotKeyID.id] else {
                    return
                }
                manager.onTrigger?(action)
            }

            return noErr
        }

        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType, nil, &eventHandler)
    }
}

private extension String {
    var fourCharCodeValue: UInt32 {
        utf8.prefix(4).reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
