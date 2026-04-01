import XCTest
@testable import FluentCore

final class ShortcutModelsTests: XCTestCase {
    func testShortcutDescriptionAndComponents() {
        let action = ShortcutAction(name: "Translate", keyCode: 31, modifiers: 4096 + 2048 + 512 + 256, prompt: "Prompt")

        XCTAssertEqual(action.shortcutComponents, ["Control", "Option", "Shift", "Cmd", "O"])
        XCTAssertEqual(action.shortcutDescription, "Control+Option+Shift+Cmd+O")
    }

    func testShortcutHelpers() {
        let first = ShortcutAction(name: "One", keyCode: 31, modifiers: 768, prompt: "Prompt")
        let second = ShortcutAction(name: "Two", keyCode: 31, modifiers: 768, prompt: "Other")
        let third = ShortcutAction(name: "Three", keyCode: 34, modifiers: 768, prompt: "Other")
        let unknown = ShortcutAction(name: "Four", keyCode: 777, modifiers: 256, prompt: "Other")

        XCTAssertTrue(first.usesSameShortcut(as: second))
        XCTAssertFalse(first.usesSameShortcut(as: third))
        XCTAssertNil(ShortcutAction.keyCodeToName(777))
        XCTAssertEqual(unknown.shortcutDescription, "Cmd+Key(777)")
    }

    func testShortcutCatalogDefaultsAndTemplates() {
        XCTAssertEqual(ShortcutCatalog.templates.count, 5)
        XCTAssertEqual(ShortcutCatalog.defaults.count, 3)
        XCTAssertEqual(ShortcutCatalog.defaults.first?.name, "Translate")
        XCTAssertFalse(ShortcutCatalog.templates[2].isEnabled)
        XCTAssertEqual(ShortcutCatalog.templates[3].makeAction().name, "Summarize")
    }

    func testShortcutActionFormValidationAndCreation() {
        let existing = ShortcutAction(name: "Translate", keyCode: 31, modifiers: 768, prompt: "Prompt")
        let form = ShortcutActionForm(name: "  Summary  ", keyCode: 31, modifiers: 768, prompt: "  Prompt  ", isEnabled: true)

        let messages = form.validationMessages(existingActions: [existing], editingID: nil)

        XCTAssertEqual(messages, ["That keyboard shortcut is already in use."])

        let action = form.makeAction(existingID: existing.id)
        XCTAssertEqual(action.id, existing.id)
        XCTAssertEqual(action.name, "Summary")
        XCTAssertEqual(action.prompt, "Prompt")
        XCTAssertEqual(form.shortcutPreview, "Shift+Cmd+O")

        let newAction = form.makeAction()
        XCTAssertNotEqual(newAction.id, existing.id)
    }

    func testShortcutActionFormReportsAllMissingValues() {
        let form = ShortcutActionForm()

        XCTAssertEqual(
            form.validationMessages(existingActions: [], editingID: nil),
            ["Name is required.", "Instructions are required.", "Shortcut modifiers are required."]
        )
        XCTAssertEqual(form.shortcutPreview, "Not set")
    }

    func testShortcutActionFormInitFromAction() {
        let action = ShortcutAction(name: "Improve", keyCode: 34, modifiers: 768, prompt: "Improve text", isEnabled: false)
        let form = ShortcutActionForm(action: action)

        XCTAssertEqual(form.name, "Improve")
        XCTAssertEqual(form.keyCode, 34)
        XCTAssertEqual(form.modifiers, 768)
        XCTAssertEqual(form.prompt, "Improve text")
        XCTAssertFalse(form.isEnabled)
    }
}
