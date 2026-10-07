import AppKit

/// Moves the window from the empty space of a `windowMoveZone()` in its title bar, where the window can't be moved by
/// AppKit, so a tab or label there takes its own drag instead. AppKit moves a window from a press in its title bar on
/// any view that allows it, and every SwiftUI view does, so without the zone, dragging a tab would move the window.
///
/// While the pointer is over a zone, its window can't be moved. A press on a view marked with
/// `windowMoveZoneExclusion()`, or on an AppKit control such as a scroller, goes to it. A press anywhere else in the
/// zone moves the window, handed to the system with `performDrag(with:)` as a title bar does, or zooms or minimizes it
/// on a double-click, as chosen in System Settings. Out of the zones, the window moves as usual, and is movable, which
/// the Window menu's Move & Resize items and tiling need: they turn off for a window that can't move, as Zed found
/// when it made its windows unmovable.
@MainActor
final class WindowMoveZoneMonitor {
    static let shared = WindowMoveZoneMonitor()

    enum Response: Equatable {
        /// The press goes on to the window, as usual.
        case pass
        /// The press goes to a view in a zone that takes its own drags, with the window held still.
        case holdWindowStill
        /// The press moves the window, and goes nowhere else.
        case moveWindow
    }

    private let zones = NSHashTable<NSView>.weakObjects()
    private let exclusions = NSHashTable<NSView>.weakObjects()
    private var eventMonitor: Any?

    func register(zone: NSView) {
        zones.add(zone)
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            let goesOn = MainActor.assumeIsolated { WindowMoveZoneMonitor.shared.handle(event) }
            return goesOn ? event : nil
        }
    }

    func unregister(zone: NSView) {
        zones.remove(zone)
    }

    func register(exclusion: NSView) {
        exclusions.add(exclusion)
    }

    func unregister(exclusion: NSView) {
        exclusions.remove(exclusion)
    }

    /// Runs before the window handles the event, and returns whether the event goes on to the window.
    func handle(_ event: NSEvent) -> Bool {
        guard let window = event.window else { return true }
        switch response(to: event) {
        case .pass:
            // A release, or a press out of the zones, after the pointer left a zone unseen, such as while a window
            // drag carried it along.
            if !isInZone(event.locationInWindow, of: window), hasZone(in: window) { window.isMovable = true }
            return true
        case .holdWindowStill:
            // The pointer can be over the zone without having entered it, as when the window opened under it.
            window.isMovable = false
            return true
        case .moveWindow:
            moveWindow(window, from: event)
            return false
        }
    }

    func response(to event: NSEvent) -> Response {
        guard event.type == .leftMouseDown, let window = event.window else { return .pass }
        let point = event.locationInWindow
        guard isInZone(point, of: window) else { return .pass }
        if isOnExclusion(point, in: window) || window.contentView?.superview?.hitTest(point) is NSControl {
            return .holdWindowStill
        }
        return .moveWindow
    }

    private func moveWindow(_ window: NSWindow, from event: NSEvent) {
        // The zone stands in for a title bar, so it moves no window without one, nor one in full screen.
        guard window.styleMask.contains(.titled), !window.styleMask.contains(.fullScreen) else { return }
        if event.clickCount == 2 {
            TitleBarDoubleClickAction.chosenInSystemSettings.perform(on: window)
            return
        }
        // An unmovable window keeps its place on screen. The drag runs until the button comes up, with the pointer
        // still over the zone, which the window followed.
        window.isMovable = true
        window.performDrag(with: event)
        window.isMovable = false
    }

    private func hasZone(in window: NSWindow) -> Bool {
        zones.allObjects.contains { $0.window === window }
    }

    private func isInZone(_ point: NSPoint, of window: NSWindow) -> Bool {
        zones.allObjects.contains { $0.window === window && Self.areaInSight(of: $0).contains(point) }
    }

    private func isOnExclusion(_ point: NSPoint, in window: NSWindow) -> Bool {
        exclusions.allObjects.contains { $0.window === window && Self.areaInSight(of: $0).contains(point) }
    }

    /// In window coordinates, or nothing for a hidden view. Clipped by hand to the scroll view a view is in, such as a
    /// tab partly scrolled out of the tab bar: a view SwiftUI hosts reports all of its scroll view as its `visibleRect`.
    private static func areaInSight(of view: NSView) -> NSRect {
        guard !view.isHiddenOrHasHiddenAncestor else { return .zero }
        let frame = view.convert(view.bounds, to: nil)
        guard let clipView = view.enclosingScrollView?.contentView else { return frame }
        return frame.intersection(clipView.convert(clipView.bounds, to: nil))
    }
}
