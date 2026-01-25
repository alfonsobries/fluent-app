import XCTest

// Since we can't directly import the executable, we copy the relevant code for testing
// This tests the ShortcutAction model logic

struct TestShortcutAction: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var keyCode: UInt32
    var modifiers: UInt32
    var prompt: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        keyCode: UInt32,
        modifiers: UInt32,
        prompt: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    var shortcutDescription: String {
        var parts: [String] = []

        if modifiers & 4096 != 0 { parts.append("Control") }
        if modifiers & 2048 != 0 { parts.append("Option") }
        if modifiers & 512 != 0 { parts.append("Shift") }
        if modifiers & 256 != 0 { parts.append("Cmd") }

        if let keyName = Self.keyCodeToName(keyCode) {
            parts.append(keyName)
        } else {
            parts.append("Key(\(keyCode))")
        }

        return parts.joined(separator: "+")
    }

    static func keyCodeToName(_ code: UInt32) -> String? {
        let keyNames: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 31: "O", 34: "I", 35: "P", 37: "L"
        ]
        return keyNames[code]
    }
}

final class ShortcutActionTests: XCTestCase {

    func testShortcutActionCreation() {
        let action = TestShortcutAction(
            name: "Test",
            keyCode: 31,
            modifiers: 768,
            prompt: "Test prompt"
        )

        XCTAssertEqual(action.name, "Test")
        XCTAssertEqual(action.keyCode, 31)
        XCTAssertEqual(action.modifiers, 768)
        XCTAssertEqual(action.prompt, "Test prompt")
        XCTAssertTrue(action.isEnabled)
    }

    func testShortcutDescription_CmdShiftO() {
        let action = TestShortcutAction(
            name: "Translate",
            keyCode: 31, // O
            modifiers: 768, // Cmd (256) + Shift (512)
            prompt: "Translate"
        )

        XCTAssertEqual(action.shortcutDescription, "Shift+Cmd+O")
    }

    func testShortcutDescription_CmdShiftI() {
        let action = TestShortcutAction(
            name: "Improve",
            keyCode: 34, // I
            modifiers: 768, // Cmd + Shift
            prompt: "Improve"
        )

        XCTAssertEqual(action.shortcutDescription, "Shift+Cmd+I")
    }

    func testShortcutDescription_AllModifiers() {
        let action = TestShortcutAction(
            name: "Test",
            keyCode: 0, // A
            modifiers: 4096 + 2048 + 512 + 256, // Control + Option + Shift + Cmd
            prompt: "Test"
        )

        XCTAssertEqual(action.shortcutDescription, "Control+Option+Shift+Cmd+A")
    }

    func testShortcutActionEquality() {
        let id = UUID()
        let action1 = TestShortcutAction(
            id: id,
            name: "Test",
            keyCode: 31,
            modifiers: 768,
            prompt: "Test"
        )
        let action2 = TestShortcutAction(
            id: id,
            name: "Test",
            keyCode: 31,
            modifiers: 768,
            prompt: "Test"
        )

        XCTAssertEqual(action1, action2)
    }

    func testShortcutActionCodable() throws {
        let action = TestShortcutAction(
            name: "Translate",
            keyCode: 31,
            modifiers: 768,
            prompt: "Translate text"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(action)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TestShortcutAction.self, from: data)

        XCTAssertEqual(action.name, decoded.name)
        XCTAssertEqual(action.keyCode, decoded.keyCode)
        XCTAssertEqual(action.modifiers, decoded.modifiers)
        XCTAssertEqual(action.prompt, decoded.prompt)
    }
}
