import AppKit
import GhosttyTerminal

/// Ghostty calls this for a ⌘-click on a link, with an OSC 8 hyperlink's target or the URL or path it found. Being this
/// delegate tells Ghostty the app opens links itself. Without one, Ghostty would run `open` on any URL or path it
/// found, which opens no relative path, and would open no OSC 8 hyperlink at all.
extension GhosttyTabTerminalView: TerminalSurfaceOpenURLDelegate {
    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        guard let pendingHardWrappedLink else {
            onOpenLink?(url)
            return
        }
        self.pendingHardWrappedLink = nil
        onOpenLink?(pendingHardWrappedLink.resolved(engineLink: url))
    }

    /// While a program takes the mouse, as tmux does in every CLI tab on this Mac, Ghostty looks for links only with
    /// Shift held, the key that takes the mouse back from the program, and then matches them without it. SwiftTerm
    /// finds them with ⌘ alone. So a move or left-button event with ⌘ held goes to Ghostty with Shift as well, which
    /// also keeps the click from the program.
    func eventFindingLinks(_ event: NSEvent) -> NSEvent {
        let modifierFlags = event.modifierFlags
        guard modifierFlags.contains(.command), !modifierFlags.contains(.shift), terminalSurface?.isMouseCaptured == true,
            let shiftedEvent = NSEvent.mouseEvent(
                with: event.type, location: event.locationInWindow, modifierFlags: modifierFlags.union(.shift),
                timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil,
                eventNumber: event.eventNumber, clickCount: event.type == .mouseMoved ? 0 : event.clickCount,
                pressure: event.pressure
            )
        else { return event }
        return shiftedEvent
    }

    func link(under event: NSEvent) -> String? {
        let ghosttyLink = ghosttyLink(under: event)
        guard let hardWrappedLink = hardWrappedLink(under: event) else { return ghosttyLink }
        return hardWrappedLink.resolved(engineLink: ghosttyLink)
    }

    /// The link Ghostty finds where `event` happened. Ghostty looks for links only while ⌘ is held, so the pointer
    /// moves to the same place with ⌘ for Ghostty to report the link, then moves there again with the keys really
    /// held, which clears the link's underline. Ghostty skips the look when the pointer stays in the cell it last
    /// looked in, so the pointer first leaves the terminal, as it does when it leaves the view.
    private func ghosttyLink(under event: NSEvent) -> String? {
        guard let terminalSurface, bounds.contains(convert(event.locationInWindow, from: nil)),
            let commandMove = pointerMove(like: event, modifierFlags: .command),
            let restoringMove = pointerMove(like: event, modifierFlags: event.modifierFlags)
        else { return nil }
        hoveredLink = nil
        terminalSurface.sendMousePos(x: -1, y: -1, modifiers: TerminalInputModifiers(from: event.modifierFlags))
        mouseMoved(with: commandMove)
        let link = hoveredLink
        mouseMoved(with: restoringMove)
        return link
    }

    private func pointerMove(like event: NSEvent, modifierFlags: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.mouseEvent(
            with: .mouseMoved, location: event.locationInWindow, modifierFlags: modifierFlags,
            timestamp: event.timestamp, windowNumber: event.windowNumber, context: nil, eventNumber: 0, clickCount: 0,
            pressure: 0
        )
    }
}

extension GhosttyTabTerminalView: TerminalSurfaceHoverLinkDelegate {
    func terminalDidUpdateHoverLink(_ url: String?) {
        hoveredLink = url
    }
}
