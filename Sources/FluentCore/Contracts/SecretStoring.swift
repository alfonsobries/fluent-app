import Foundation

public protocol SecretStoring {
    func secret(for account: String) throws -> String?
    func setSecret(_ secret: String, for account: String) throws
    func removeSecret(for account: String) throws
}

public final class InMemorySecretStore: SecretStoring {
    private var secrets: [String: String]

    public init(secrets: [String: String] = [:]) {
        self.secrets = secrets
    }

    public func secret(for account: String) throws -> String? {
        secrets[account]
    }

    public func setSecret(_ secret: String, for account: String) throws {
        secrets[account] = secret
    }

    public func removeSecret(for account: String) throws {
        secrets[account] = nil
    }
}
