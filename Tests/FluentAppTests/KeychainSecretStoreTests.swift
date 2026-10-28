import FluentMacSupport
import Security
import XCTest

final class KeychainSecretStoreTests: XCTestCase {
    private var store: KeychainSecretStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        store = KeychainSecretStore(service: "com.alfonsobries.fluent.tests.\(UUID().uuidString)")

        // CI machines without an unlocked login keychain can't run these.
        do {
            try store.setSecret("probe", for: "probe")
            try store.removeSecret(for: "probe")
        } catch let error as KeychainError {
            throw XCTSkip("Keychain unavailable: \(error.localizedDescription)")
        }
    }

    override func tearDownWithError() throws {
        try store?.removeSecret(for: "openai")
        store = nil
        try super.tearDownWithError()
    }

    func testStoresUpdatesAndRemovesSecrets() throws {
        XCTAssertNil(try store.secret(for: "openai"))

        try store.setSecret("sk-first", for: "openai")
        XCTAssertEqual(try store.secret(for: "openai"), "sk-first")

        try store.setSecret("sk-second", for: "openai")
        XCTAssertEqual(try store.secret(for: "openai"), "sk-second")

        try store.removeSecret(for: "openai")
        XCTAssertNil(try store.secret(for: "openai"))
        XCTAssertNoThrow(try store.removeSecret(for: "openai"))
    }

    func testErrorDescriptionIncludesStatus() {
        let error = KeychainError(status: errSecAuthFailed)

        XCTAssertTrue(error.errorDescription?.contains("\(errSecAuthFailed)") ?? false)
    }
}
