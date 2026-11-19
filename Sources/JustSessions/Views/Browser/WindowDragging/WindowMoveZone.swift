import AppKit
import SwiftUI

extension View {
    func windowMoveZone() -> some View {
        background(WindowMoveZone())
    }

    func windowMoveZoneExclusion() -> some View {
        background(WindowMoveZoneExclusion())
    }
}

/// The window server can start moving the window from the title bar before the app sees the press.
private struct WindowMoveZone: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowMoveZoneView { WindowMoveZoneView() }

    func updateNSView(_ view: WindowMoveZoneView, context: Context) {}
}

final class WindowMoveZoneView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

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
        addTrackingArea(
            NSTrackingArea(
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
