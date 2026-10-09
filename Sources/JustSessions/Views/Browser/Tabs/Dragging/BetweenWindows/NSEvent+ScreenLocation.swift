import AppKit

extension NSEvent {
    /// Where a mouse event happened, in screen coordinates, whichever window it went to, and wherever that window has
    /// moved since. Mouse events another app posts, as accessibility tools do, leave the cursor where it was, so
    /// `NSEvent.mouseLocation` can be elsewhere.
    @MainActor var screenLocation: CGPoint {
        guard let location = cgEvent?.location, let primaryScreen = NSScreen.screens.first else {
            return window?.convertPoint(toScreen: locationInWindow) ?? locationInWindow
        }
        // Quartz measures from the top of the primary screen; AppKit, from its bottom.
        return CGPoint(x: location.x, y: primaryScreen.frame.maxY - location.y)
    }

    /// Where the mouse event being handled happened, in screen coordinates, or the cursor's location outside one.
    @MainActor static var currentPointerLocation: CGPoint {
        guard let event = NSApp.currentEvent,
              [.leftMouseDown, .leftMouseDragged, .leftMouseUp].contains(event.type) else { return mouseLocation }
        return event.screenLocation
    }
}
