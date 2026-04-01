import FluentCore

public extension AppController {
    static func live() -> AppController {
        AppController(
            settings: AppSettings(
                providerFactory: .live,
                launchAtLoginController: SMAppLaunchController()
            ),
            clipboardService: LiveClipboardService(),
            hotKeyManager: LiveHotKeyManager.shared
        )
    }
}
