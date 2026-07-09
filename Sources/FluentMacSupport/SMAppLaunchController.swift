import FluentCore
import ServiceManagement

public struct SMAppLaunchController: LaunchAtLoginControlling {
    public init() {}

    // Registering from a raw executable (swift run, .build binaries) or any
    // ad-hoc copy creates a login item that macOS opens in Terminal at boot
    // and that lingers after the copy is deleted. Only a real .app bundle
    // may manage launch-at-login.
    private var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard isAppBundle else { return }

        let service = SMAppService.mainApp

        if enabled, service.status != .enabled {
            try service.register()
        } else if !enabled, service.status == .enabled {
            try service.unregister()
        }
    }
}
