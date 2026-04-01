import FluentCore
import ServiceManagement

public struct SMAppLaunchController: LaunchAtLoginControlling {
    public init() {}

    public var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp

        if enabled, service.status != .enabled {
            try service.register()
        } else if !enabled, service.status == .enabled {
            try service.unregister()
        }
    }
}
