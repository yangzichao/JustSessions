import AppKit
import Carbon.HIToolbox
import Testing
@testable import JustSessions

@MainActor
struct ZoomInEqualsKeyTests {
    @Test func onlyCommandEqualsStandsForCommandPlus() {
        #expect(ZoomInEqualsKey.zoomInEvent(for: equalsKey(modifiers: .command))?.charactersIgnoringModifiers == "+")
        #expect(ZoomInEqualsKey.zoomInEvent(for: equalsKey(modifiers: [.command, .capsLock, .function])) != nil)
        for modifiers: NSEvent.ModifierFlags in [[], .shift, [.command, .shift], [.command, .option], [.command, .control]] {
            #expect(ZoomInEqualsKey.zoomInEvent(for: equalsKey(modifiers: modifiers)) == nil)
        }
        #expect(ZoomInEqualsKey.zoomInEvent(for: equalsKey(modifiers: .command, type: .keyUp)) == nil)
    }

    /// A menu item takes one key equivalent: Zoom In's ⌘+ misses ⌘=, and catches the ⌘+ that ⌘= is handed on as.
    @Test func theHandedOnEventChoosesTheCommandPlusMenuItem() throws {
        _ = NSApplication.shared
        let menu = NSMenu()
        let zoomIn = MenuItemChoices()
        let item = NSMenuItem(title: "Zoom In", action: #selector(MenuItemChoices.choose(_:)), keyEquivalent: "+")
        item.keyEquivalentModifierMask = .command
        item.target = zoomIn
        menu.addItem(item)

        let commandEquals = equalsKey(modifiers: .command)
        #expect(!menu.performKeyEquivalent(with: commandEquals))
        #expect(menu.performKeyEquivalent(with: try #require(ZoomInEqualsKey.zoomInEvent(for: commandEquals))))
        #expect(zoomIn.count == 1)
    }

    private func equalsKey(modifiers: NSEvent.ModifierFlags, type: NSEvent.EventType = .keyDown) -> NSEvent {
        NSEvent.keyEvent(
            with: type, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
            characters: "=", charactersIgnoringModifiers: "=", isARepeat: false, keyCode: UInt16(kVK_ANSI_Equal)
        )!
    }
}

private final class MenuItemChoices: NSObject {
    var count = 0
    @objc func choose(_ sender: NSMenuItem) { count += 1 }
}
