import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct GhosttyKeyBindingTests {
    @Test func keysSendWhatSwiftTermSends() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.window.makeFirstResponder(terminal.view)
        let escape = "\u{1B}"

        for (key, swiftTermBytes) in [
            (USKey.commandLeft, "\u{01}"),
            (.commandRight, "\u{05}"),
            (.commandDelete, "\u{15}"),
            (.commandZ, "\u{1F}"),
            (.optionLeft, escape + "b"),
            (.optionRight, escape + "f"),
            // SwiftTerm handles neither `moveToBeginningOfDocument:` nor `moveToEndOfDocument:`.
            (.commandUp, ""),
            (.commandDown, ""),
            (.optionDelete, escape + "\u{7F}"),
            (.home, escape + "[H"),
            (.end, escape + "[F"),
        ] {
            #expect(try await terminal.bytesSent(pressing: key) == Array(swiftTermBytes.utf8), "\(key)")
        }
    }

    @Test func optionIsMetaUntilTurnedOffInAnOpenTerminal() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.window.makeFirstResponder(terminal.view)
        let escape = UInt8(0x1B)
        let optionB = USKey(description: "Option-B", keyCode: 11, characters: "b", modifierFlags: .option)

        #expect(try await terminal.bytesSent(pressing: optionB) == [escape, UInt8(ascii: "b")])

        stores.optionKey.setOptionIsMeta(false)

        let typed = try await terminal.bytesSent(pressing: optionB)
        #expect(!typed.isEmpty && !typed.contains(escape), "\(typed)")
        #expect(try await terminal.bytesSent(pressing: .optionLeft) == [escape, UInt8(ascii: "b")])

        stores.optionKey.setOptionIsMeta(true)

        #expect(try await terminal.bytesSent(pressing: optionB) == [escape, UInt8(ascii: "b")])
    }

    /// The app's menus' shortcuts: Ghostty, whose own shortcuts would close the terminal on Command-W and open a tab on
    /// Command-T, leaves each to the menu. Command-Z is a line editing key the terminal takes; see `TerminalEditingKey`.
    @Test func theAppsMenuShortcutsReachTheMenu() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.window.makeFirstResponder(terminal.view)
        #expect(terminal.window.firstResponder === terminal.view)

        let command = NSEvent.ModifierFlags.command
        let shortcuts: [USKey] =
            [
                USKey(description: "Command-N", keyCode: 45, characters: "n", modifierFlags: command),
                USKey(description: "Command-T", keyCode: 17, characters: "t", modifierFlags: command),
                USKey(description: "Shift-Command-N", keyCode: 45, characters: "N", modifierFlags: [.command, .shift]),
                USKey(description: "Command-W", keyCode: 13, characters: "w", modifierFlags: command),
                USKey(description: "Shift-Command-[", keyCode: 33, characters: "{", modifierFlags: [.command, .shift]),
                USKey(description: "Shift-Command-]", keyCode: 30, characters: "}", modifierFlags: [.command, .shift]),
            ]
            + zip(1...9, [18, 19, 20, 21, 23, 22, 26, 28, 25]).map { number, keyCode in
                USKey(description: "Command-\(number)", keyCode: UInt16(keyCode), characters: "\(number)", modifierFlags: command)
            } + [
                USKey(description: "Command-B", keyCode: 11, characters: "b", modifierFlags: command),
                USKey(description: "Command-,", keyCode: 43, characters: ",", modifierFlags: command),
                USKey(description: "Shift-Command-Z", keyCode: 6, characters: "Z", modifierFlags: [.command, .shift]),
                USKey(description: "Command-X", keyCode: 7, characters: "x", modifierFlags: command),
                USKey(description: "Command-C", keyCode: 8, characters: "c", modifierFlags: command),
                USKey(description: "Command-V", keyCode: 9, characters: "v", modifierFlags: command),
                USKey(description: "Command-A", keyCode: 0, characters: "a", modifierFlags: command),
                USKey(description: "Command-Q", keyCode: 12, characters: "q", modifierFlags: command),
                USKey(description: "Command-H", keyCode: 4, characters: "h", modifierFlags: command),
                USKey(description: "Command-M", keyCode: 46, characters: "m", modifierFlags: command),
                USKey(description: "Command-0", keyCode: 29, characters: "0", modifierFlags: command),
                USKey(description: "Shift-Command-=", keyCode: 24, characters: "+", modifierFlags: [.command, .shift]),
                USKey(description: "Command-=", keyCode: 24, characters: "=", modifierFlags: command),
                USKey(description: "Command--", keyCode: 27, characters: "-", modifierFlags: command),
                // TranscriptBookmarkCommands: without Ghostty's shortcuts cleared, Command-D would split the terminal
                USKey(description: "Command-D", keyCode: 2, characters: "d", modifierFlags: command),
                USKey(description: "Command-'", keyCode: 39, characters: "'", modifierFlags: command),
                USKey(description: "Shift-Command-'", keyCode: 39, characters: "\"", modifierFlags: [.command, .shift]),
            ]
        for shortcut in shortcuts {
            #expect(!terminal.view.performKeyEquivalent(with: terminal.keyEvent(shortcut, .keyDown)), "\(shortcut)")
        }
    }
}

extension USKey {
    private static let arrow: NSEvent.ModifierFlags = [.function, .numericPad]

    private static func functionKey(_ scalar: Int) -> String {
        String(UnicodeScalar(UInt32(scalar))!)
    }

    static let commandLeft = USKey(
        description: "Command-Left", keyCode: 123, characters: functionKey(NSLeftArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandRight = USKey(
        description: "Command-Right", keyCode: 124, characters: functionKey(NSRightArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let optionLeft = USKey(
        description: "Option-Left", keyCode: 123, characters: functionKey(NSLeftArrowFunctionKey), modifierFlags: arrow.union(.option))
    static let optionRight = USKey(
        description: "Option-Right", keyCode: 124, characters: functionKey(NSRightArrowFunctionKey), modifierFlags: arrow.union(.option))
    static let commandUp = USKey(
        description: "Command-Up", keyCode: 126, characters: functionKey(NSUpArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandDown = USKey(
        description: "Command-Down", keyCode: 125, characters: functionKey(NSDownArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandDelete = USKey(description: "Command-Delete", keyCode: 51, characters: "\u{7F}", modifierFlags: .command)
    static let commandZ = USKey(description: "Command-Z", keyCode: 6, characters: "z", modifierFlags: .command)
    static let optionDelete = USKey(description: "Option-Delete", keyCode: 51, characters: "\u{7F}", modifierFlags: .option)
    static let home = USKey(description: "Home", keyCode: 115, characters: functionKey(NSHomeFunctionKey), modifierFlags: .function)
    static let end = USKey(description: "End", keyCode: 119, characters: functionKey(NSEndFunctionKey), modifierFlags: .function)
}
