import XCTest

// Test launch at startup settings persistence logic
// Note: SMAppService cannot be tested in unit tests as it requires a signed app bundle

final class LaunchAtStartupTests: XCTestCase {

    // Test UserDefaults key constant
    let launchAtStartupKey = "launchAtStartup"

    override func setUp() {
        super.setUp()
        // Clean up UserDefaults before each test
        UserDefaults.standard.removeObject(forKey: launchAtStartupKey)
    }

    override func tearDown() {
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: launchAtStartupKey)
        super.tearDown()
    }

    func testDefaultValueIsTrue() {
        // When no value is stored, the default should be true
        let hasStoredValue = UserDefaults.standard.object(forKey: launchAtStartupKey) != nil
        XCTAssertFalse(hasStoredValue, "No value should be stored initially")

        // Simulate the app's default behavior: if no value exists, default to true
        let defaultValue: Bool
        if UserDefaults.standard.object(forKey: launchAtStartupKey) != nil {
            defaultValue = UserDefaults.standard.bool(forKey: launchAtStartupKey)
        } else {
            defaultValue = true // Default for new users
        }

        XCTAssertTrue(defaultValue, "Default value should be true for new users")
    }

    func testSavingTrueValue() {
        UserDefaults.standard.set(true, forKey: launchAtStartupKey)

        let savedValue = UserDefaults.standard.bool(forKey: launchAtStartupKey)
        XCTAssertTrue(savedValue)
    }

    func testSavingFalseValue() {
        UserDefaults.standard.set(false, forKey: launchAtStartupKey)

        let savedValue = UserDefaults.standard.bool(forKey: launchAtStartupKey)
        XCTAssertFalse(savedValue)
    }

    func testTogglePersistence() {
        // Start with true
        UserDefaults.standard.set(true, forKey: launchAtStartupKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: launchAtStartupKey))

        // Toggle to false
        UserDefaults.standard.set(false, forKey: launchAtStartupKey)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: launchAtStartupKey))

        // Toggle back to true
        UserDefaults.standard.set(true, forKey: launchAtStartupKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: launchAtStartupKey))
    }

    func testValueExistsAfterFirstSave() {
        // Initially no value exists
        XCTAssertNil(UserDefaults.standard.object(forKey: launchAtStartupKey))

        // Save a value
        UserDefaults.standard.set(true, forKey: launchAtStartupKey)

        // Now value should exist
        XCTAssertNotNil(UserDefaults.standard.object(forKey: launchAtStartupKey))
    }
}
