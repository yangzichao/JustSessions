import AppKit

/// Chrome zooms in on ⌘= as well as on the ⌘+ its View menu shows, so zooming in needs no Shift. A menu item has one
/// key equivalent, and ⌘+ does not match ⌘=, so this hands ⌘= to the menu as ⌘+.
@MainActor
enum ZoomInEqualsKey {
    private static var monitor: Any?

    static func startForwarding() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let isHandled = MainActor.assumeIsolated {
                zoomInEvent(for: event).map { NSApp.mainMenu?.performKeyEquivalent(with: $0) == true } ?? false
            }
            return isHandled ? nil : event
        }
    }

    /// The ⌘+ that a ⌘= stands for, or nil for any other key. Caps Lock and Fn do not change the shortcut.
    static func zoomInEvent(for event: NSEvent) -> NSEvent? {
        guard event.type == .keyDown,
              event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
              event.charactersIgnoringModifiers == "=" else { return nil }
        return NSEvent.keyEvent(
            with: .keyDown,
            location: event.locationInWindow,
            modifierFlags: event.modifierFlags.union(.shift),
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            characters: "+",
            charactersIgnoringModifiers: "+",
            isARepeat: event.isARepeat,
            keyCode: event.keyCode
        )
    }
}
