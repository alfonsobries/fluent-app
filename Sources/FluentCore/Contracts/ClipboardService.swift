import Foundation

public protocol ClipboardServicing {
    func checkAccessibilityPermissions(prompt: Bool) -> Bool
    func copySelectedText() -> String?
    func pasteText(_ text: String)
}
