import AppKit
import Testing
@testable import JustSessions

/// The keys of a Ghostty terminal drawn with a controller from `GhosttyTerminalControllers`, whose configuration clears
/// Ghostty's own shortcuts and binds some keys as SwiftTerm sends them.
@MainActor
@Suite(.serialized)
struct GhosttyKeyBindingTests {
    /// What a SwiftTerm terminal sends for each key with the US layout, outside the kitty keyboard protocol: its
    /// `keyDown`, then the commands macOS's standard key bindings give `doCommand(by:)`. Option-Delete, Home, and End
    /// already send the same in Ghostty, and are here to keep it that way.
    @Test func keysSendWhatSwiftTermSends() async throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.window.makeFirstResponder(terminal.view)
        let escape = "\u{1B}"

        for (key, swiftTermBytes) in [
            (USKey.commandLeft, escape + "b"),
            (.commandRight, escape + "f"),
            (.optionLeft, escape + "b"),
            (.optionRight, escape + "f"),
            // SwiftTerm handles none of `deleteToBeginningOfLine:`, `moveToBeginningOfDocument:`, and
            // `moveToEndOfDocument:`.
            (.commandDelete, ""),
            (.commandUp, ""),
            (.commandDown, ""),
            (.optionDelete, escape + "\u{7F}"),
            (.home, escape + "[H"),
            (.end, escape + "[F"),
        ] {
            #expect(try await terminal.bytesSent(pressing: key) == Array(swiftTermBytes.utf8), "\(key)")
        }
    }

    /// The app's menus' shortcuts: Ghostty, whose own shortcuts would close the terminal on Command-W and open a tab on
    /// Command-T, leaves each to the menu.
    @Test func theAppsMenuShortcutsReachTheMenu() throws {
        let stores = try IsolatedAppearanceStores()
        defer { stores.remove() }
        let terminal = GhosttyTestTerminal(controller: stores.controller(), appearance: .aqua)
        terminal.window.makeFirstResponder(terminal.view)
        #expect(terminal.window.firstResponder === terminal.view)

        let command = NSEvent.ModifierFlags.command
        let shortcuts: [USKey] = [
            // WorkspaceTabCommands
            USKey(description: "Command-N", keyCode: 45, characters: "n", modifierFlags: command),
            USKey(description: "Command-T", keyCode: 17, characters: "t", modifierFlags: command),
            USKey(description: "Shift-Command-N", keyCode: 45, characters: "N", modifierFlags: [.command, .shift]),
            USKey(description: "Command-W", keyCode: 13, characters: "w", modifierFlags: command),
            USKey(description: "Shift-Command-[", keyCode: 33, characters: "{", modifierFlags: [.command, .shift]),
            USKey(description: "Shift-Command-]", keyCode: 30, characters: "}", modifierFlags: [.command, .shift]),
        ] + zip(1...9, [18, 19, 20, 21, 23, 22, 26, 28, 25]).map { number, keyCode in
            USKey(description: "Command-\(number)", keyCode: UInt16(keyCode), characters: "\(number)", modifierFlags: command)
        } + [
            // SidebarToggleCommands and AppWideSheetCommands
            USKey(description: "Command-B", keyCode: 11, characters: "b", modifierFlags: command),
            USKey(description: "Command-,", keyCode: 43, characters: ",", modifierFlags: command),
            // The Edit menu
            USKey(description: "Command-Z", keyCode: 6, characters: "z", modifierFlags: command),
            USKey(description: "Shift-Command-Z", keyCode: 6, characters: "Z", modifierFlags: [.command, .shift]),
            USKey(description: "Command-X", keyCode: 7, characters: "x", modifierFlags: command),
            USKey(description: "Command-C", keyCode: 8, characters: "c", modifierFlags: command),
            USKey(description: "Command-V", keyCode: 9, characters: "v", modifierFlags: command),
            USKey(description: "Command-A", keyCode: 0, characters: "a", modifierFlags: command),
            // The app and window menus
            USKey(description: "Command-Q", keyCode: 12, characters: "q", modifierFlags: command),
            USKey(description: "Command-H", keyCode: 4, characters: "h", modifierFlags: command),
            USKey(description: "Command-M", keyCode: 46, characters: "m", modifierFlags: command),
            // TextZoomCommands: Actual Size, Zoom In (also Command-=), and Zoom Out, which size the terminals' font
            USKey(description: "Command-0", keyCode: 29, characters: "0", modifierFlags: command),
            USKey(description: "Shift-Command-=", keyCode: 24, characters: "+", modifierFlags: [.command, .shift]),
            USKey(description: "Command-=", keyCode: 24, characters: "=", modifierFlags: command),
            USKey(description: "Command--", keyCode: 27, characters: "-", modifierFlags: command),
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

    static let commandLeft = USKey(description: "Command-Left", keyCode: 123, characters: functionKey(NSLeftArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandRight = USKey(description: "Command-Right", keyCode: 124, characters: functionKey(NSRightArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let optionLeft = USKey(description: "Option-Left", keyCode: 123, characters: functionKey(NSLeftArrowFunctionKey), modifierFlags: arrow.union(.option))
    static let optionRight = USKey(description: "Option-Right", keyCode: 124, characters: functionKey(NSRightArrowFunctionKey), modifierFlags: arrow.union(.option))
    static let commandUp = USKey(description: "Command-Up", keyCode: 126, characters: functionKey(NSUpArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandDown = USKey(description: "Command-Down", keyCode: 125, characters: functionKey(NSDownArrowFunctionKey), modifierFlags: arrow.union(.command))
    static let commandDelete = USKey(description: "Command-Delete", keyCode: 51, characters: "\u{7F}", modifierFlags: .command)
    static let optionDelete = USKey(description: "Option-Delete", keyCode: 51, characters: "\u{7F}", modifierFlags: .option)
    static let home = USKey(description: "Home", keyCode: 115, characters: functionKey(NSHomeFunctionKey), modifierFlags: .function)
    static let end = USKey(description: "End", keyCode: 119, characters: functionKey(NSEndFunctionKey), modifierFlags: .function)
}
