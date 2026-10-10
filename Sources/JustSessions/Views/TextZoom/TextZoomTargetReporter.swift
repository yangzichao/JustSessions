import AppKit
import SwiftUI

/// Tells `TextZoomTargetRegistry` what a workspace window shows: a tab's terminal, or the selected session's preview.
struct TextZoomTargetReporter: NSViewRepresentable {
    let target: TextZoomTarget

    func makeNSView(context: Context) -> TextZoomTargetReportingView { TextZoomTargetReportingView() }

    func updateNSView(_ view: TextZoomTargetReportingView, context: Context) {
        view.target = target
    }
}

final class TextZoomTargetReportingView: NSView {
    var target = TextZoomTarget.conversation
    var registry = TextZoomTargetRegistry.shared

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { registry.register(self) }
    }

    /// Clicks go to the window's content.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
