import AppKit
import SwiftUI

extension View {
    /// Makes the view's area of the title bar a zone where the app moves the window itself, so the views in it marked
    /// with `windowMoveZoneExclusion()` take their own drags; see `WindowMoveZoneMonitor`.
    func windowMoveZone() -> some View {
        background(WindowMoveZone())
    }

    /// Keeps presses on the view, inside a `windowMoveZone()`, for the view's own clicks and drags.
    func windowMoveZoneExclusion() -> some View {
        background(WindowMoveZoneExclusion())
    }
}

/// Draws nothing and takes no clicks. It follows the pointer in and out of its area, as the window has to be unmovable
/// before a press comes: the window server can start moving the window from the title bar before the app sees the
/// press.
private struct WindowMoveZone: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowMoveZoneView { WindowMoveZoneView() }

    func updateNSView(_ view: WindowMoveZoneView, context: Context) {}
}

final class WindowMoveZoneView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// A zone leaving its window, such as the tab bar as its last tab closes, leaves the window movable.
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { window?.isMovable = true }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            WindowMoveZoneMonitor.shared.unregister(zone: self)
        } else {
            WindowMoveZoneMonitor.shared.register(zone: self)
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for trackingArea in trackingAreas { removeTrackingArea(trackingArea) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        window?.isMovable = false
    }

    override func mouseExited(with event: NSEvent) {
        window?.isMovable = true
    }
}

/// Draws nothing and takes no clicks; it only marks where its view is.
private struct WindowMoveZoneExclusion: NSViewRepresentable {
    func makeNSView(context: Context) -> ExclusionView { ExclusionView() }

    func updateNSView(_ view: ExclusionView, context: Context) {}

    final class ExclusionView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                WindowMoveZoneMonitor.shared.unregister(exclusion: self)
            } else {
                WindowMoveZoneMonitor.shared.register(exclusion: self)
            }
        }
    }
}
