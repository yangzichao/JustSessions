import AppKit
import Carbon.HIToolbox

/// An arrow, Home, or End pressed with Shift, Option, Control, or several of them, and the bytes a CLI in tmux should
/// receive for it: what xterm sends, `CSI 1 ; 1+modifiers final`, with Shift 1, Option 2, and Control 4. Option-Left and
/// Option-Right alone send Esc b and Esc f instead (TRM-66), which tmux hands a CLI that asked for modifyOtherKeys as
/// `CSI 98;3u` and `CSI 102;3u`.
struct ModifiedNavigationKeyPress {
    enum Key: CaseIterable {
        case up, down, right, left, home, end
    }

    let key: Key
    let modifiers: NSEvent.ModifierFlags

    static let all: [ModifiedNavigationKeyPress] = {
        let combinations: [NSEvent.ModifierFlags] = [
            [.shift], [.option], [.shift, .option], [.control],
            [.shift, .control], [.option, .control], [.shift, .option, .control],
        ]
        return combinations.flatMap { modifiers in Key.allCases.map { ModifiedNavigationKeyPress(key: $0, modifiers: modifiers) } }
    }()

    var bytesTheCLIReceives: String {
        if modifiers == .option, key == .left { return "\u{1b}[98;3u" }
        if modifiers == .option, key == .right { return "\u{1b}[102;3u" }
        var parameter = 1
        if modifiers.contains(.shift) { parameter += 1 }
        if modifiers.contains(.option) { parameter += 2 }
        if modifiers.contains(.control) { parameter += 4 }
        return "\u{1b}[1;\(parameter)\(final)"
    }

    /// The key's event as macOS delivers it: these keys come marked as function keys, and arrows as keypad keys too.
    func event(windowNumber: Int) -> NSEvent {
        let character = String(UnicodeScalar(UInt32(functionKey))!)
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers.union(key == .home || key == .end ? [.function] : [.function, .numericPad]),
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            characters: character,
            charactersIgnoringModifiers: character,
            isARepeat: false,
            keyCode: UInt16(keyCode)
        )!
    }

    private var final: String {
        switch key {
        case .up: "A"
        case .down: "B"
        case .right: "C"
        case .left: "D"
        case .home: "H"
        case .end: "F"
        }
    }

    private var functionKey: Int {
        switch key {
        case .up: NSUpArrowFunctionKey
        case .down: NSDownArrowFunctionKey
        case .right: NSRightArrowFunctionKey
        case .left: NSLeftArrowFunctionKey
        case .home: NSHomeFunctionKey
        case .end: NSEndFunctionKey
        }
    }

    private var keyCode: Int {
        switch key {
        case .up: kVK_UpArrow
        case .down: kVK_DownArrow
        case .right: kVK_RightArrow
        case .left: kVK_LeftArrow
        case .home: kVK_Home
        case .end: kVK_End
        }
    }
}
