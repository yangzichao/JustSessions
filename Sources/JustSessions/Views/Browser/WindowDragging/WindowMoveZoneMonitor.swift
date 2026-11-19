import AppKit

/// AppKit moves a window from a press in its title bar on any view that allows it, and every SwiftUI view does, so
/// without the zone, dragging a tab would move the window. Out of the zones, the window moves as usual, and is
/// movable, which the Window menu's Move & Resize items and tiling need: they turn off for a window that can't move,
/// as Zed found when it made its windows unmovable. While a sheet covers the window, presses pass, for
/// `SheetClickOutsideMonitor` to close the sheet as a click elsewhere in the window does; both monitors see presses
/// first, in an order AppKit doesn't promise.
@MainActor
final class WindowMoveZoneMonitor {
    static let shared = WindowMoveZoneMonitor()

    enum Response: Equatable {
        case pass
        case holdWindowStill
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
        guard event.type == .leftMouseDown, let window = event.window, window.attachedSheet == nil else { return .pass }
        let point = event.locationInWindow
        guard isInZone(point, of: window) else { return .pass }
        if isOnExclusion(point, in: window) || window.contentView?.superview?.hitTest(point) is NSControl {
            return .holdWindowStill
        }
        return .moveWindow
    }

    private func moveWindow(_ window: NSWindow, from event: NSEvent) {
        guard window.styleMask.contains(.titled), !window.styleMask.contains(.fullScreen) else { return }
        if event.clickCount == 2 {
            TitleBarDoubleClickAction.chosenInSystemSettings.perform(on: window)
            return
        }
        // An unmovable window keeps its place on screen.
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

    /// Clipped by hand to the scroll view a view is in, such as a tab partly scrolled out of the tab bar: a view SwiftUI
    /// hosts reports all of its scroll view as its `visibleRect`.
    private static func areaInSight(of view: NSView) -> NSRect {
        guard !view.isHiddenOrHasHiddenAncestor else { return .zero }
        let frame = view.convert(view.bounds, to: nil)
        guard let clipView = view.enclosingScrollView?.contentView else { return frame }
        return frame.intersection(clipView.convert(clipView.bounds, to: nil))
    }
}
