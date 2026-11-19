import AppKit
import SwiftUI

struct TranscriptBookmarkTargetReporter: NSViewRepresentable {
    let target: TranscriptBookmarkCommandTarget?
    let isActive: Bool

    func makeNSView(context: Context) -> TranscriptBookmarkTargetReportingView { TranscriptBookmarkTargetReportingView() }

    func updateNSView(_ view: TranscriptBookmarkTargetReportingView, context: Context) {
        view.target = target
        view.isActive = isActive
    }
}

final class TranscriptBookmarkTargetReportingView: NSView {
    var target: TranscriptBookmarkCommandTarget?
    var isActive = false
    var registry = TranscriptBookmarkTargetRegistry.shared

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { registry.register(self) }
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
