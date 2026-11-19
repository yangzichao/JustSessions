import AppKit
import SwiftUI

/// Scrolls a long conversation's map (TAB-10) with the trackpad or mouse wheel over it. The map is one Canvas the
/// column's size, which draws the rows in view, so nothing scrolls by itself: this watches the window's scroll events,
/// takes those over its own bounds while the map can scroll, and reports how far, positive towards the newest rows.
/// It takes no clicks or hovers. Only a shown tab's map has one (PERF-89).
struct ConversationMapScrollReader: NSViewRepresentable {
    let isScrollable: Bool
    let onScroll: @MainActor (CGFloat) -> Void

    func makeNSView(context: Context) -> MonitoringView {
        let view = MonitoringView()
        view.isScrollable = isScrollable
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: MonitoringView, context: Context) {
        view.isScrollable = isScrollable
        view.onScroll = onScroll
    }

    static func dismantleNSView(_ view: MonitoringView, coordinator: ()) {
        view.stopMonitoring()
    }

    final class MonitoringView: NSView {
        var isScrollable = false
        var onScroll: (@MainActor (CGFloat) -> Void)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                let isTaken = MainActor.assumeIsolated { self?.takes(event) ?? false }
                return isTaken ? nil : event
            }
        }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        /// Whether the map takes the event; a sideways scroll, or one elsewhere, goes on.
        private func takes(_ event: NSEvent) -> Bool {
            guard isScrollable, let window, event.window === window, !isHiddenOrHasHiddenAncestor,
                bounds.contains(convert(event.locationInWindow, from: nil)), event.scrollingDeltaY != 0
            else { return false }
            let distance =
                event.hasPreciseScrollingDeltas
                ? event.scrollingDeltaY
                : event.scrollingDeltaY * ConversationMapMetrics.wheelLineHeight
            // Content follows the fingers, as in a scroll view: a positive delta shows earlier rows.
            onScroll?(-distance)
            return true
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
