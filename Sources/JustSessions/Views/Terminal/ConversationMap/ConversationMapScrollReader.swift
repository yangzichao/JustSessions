import AppKit
import SwiftUI

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
