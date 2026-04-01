import Foundation

public protocol LaunchAtLoginControlling {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

public struct NoopLaunchAtLoginController: LaunchAtLoginControlling {
    public init() {}

    public var isEnabled: Bool { false }

    public func setEnabled(_ enabled: Bool) throws {}
}
