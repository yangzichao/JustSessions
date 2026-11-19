import AppKit
import Carbon.HIToolbox
import Testing

@testable import JustSessions

/// What each key does while a CLI's prompt is selected, as in a text field with all its text selected.
struct PromptSelectionKeyActionTests {
    typealias Key = PromptSelectionTestKey

    @Test func commandKeysCopyCutPasteAndSelectAll() {
        #expect(PromptSelectionKeyAction(Key.command("c")) == .copy)
        #expect(PromptSelectionKeyAction(Key.command("x")) == .cut)
        #expect(PromptSelectionKeyAction(Key.command("v")) == .replace)
        #expect(PromptSelectionKeyAction(Key.command("a")) == .selectAllTerminalText)
        #expect(PromptSelectionKeyAction(Key.command("z")) == .passThrough)
    }

    @Test func deleteKeysDeleteThePrompt() {
        for modifiers: NSEvent.ModifierFlags in [[], .shift, .option, .command] {
            #expect(PromptSelectionKeyAction(Key.delete(modifiers: modifiers)) == .delete)
        }
        #expect(PromptSelectionKeyAction(Key.forwardDelete()) == .delete)
        #expect(PromptSelectionKeyAction(Key.delete(modifiers: .control)) == .passThrough)
    }

    @Test func typedTextReplacesThePrompt() {
        #expect(PromptSelectionKeyAction(Key.typing("k")) == .replace)
        #expect(PromptSelectionKeyAction(Key.typing("K", modifiers: .shift)) == .replace)
        #expect(PromptSelectionKeyAction(Key.typing(" ", keyCode: kVK_Space)) == .replace)
        #expect(PromptSelectionKeyAction(Key.typing("你")) == .replace)
        // Option may send Meta, which a CLI reads as a command, not text.
        #expect(PromptSelectionKeyAction(Key.typing("˚", modifiers: .option)) == .passThrough)
    }

    @Test func arrowsCollapseTheSelectionAndOtherKeysGoOn() {
        #expect(PromptSelectionKeyAction(Key.leftArrow()) == .moveToStart)
        #expect(PromptSelectionKeyAction(Key.rightArrow()) == .moveToEnd)
        #expect(PromptSelectionKeyAction(Key.leftArrow(modifiers: .shift)) == .passThrough)
        #expect(PromptSelectionKeyAction(Key.upArrow()) == .passThrough)
        #expect(PromptSelectionKeyAction(Key.escape()) == .dismiss)
        #expect(PromptSelectionKeyAction(Key.returnKey()) == .passThrough)
        #expect(PromptSelectionKeyAction(Key.control("c")) == .passThrough)
    }

    @Test func onlyCommandAIsSelectAll() {
        #expect(PromptSelectionKeyAction.isSelectAll(Key.command("a")))
        #expect(!PromptSelectionKeyAction.isSelectAll(Key.command("c")))
        #expect(!PromptSelectionKeyAction.isSelectAll(Key.typing("a", keyCode: kVK_ANSI_A)))
    }
}
