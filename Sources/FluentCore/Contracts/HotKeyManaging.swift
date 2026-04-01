import Foundation

public protocol HotKeyManaging: AnyObject {
    var isPaused: Bool { get set }
    var onTrigger: ((ShortcutAction) -> Void)? { get set }

    func registerHotKeys(for actions: [ShortcutAction])
    func unregisterAllHotKeys()
}
