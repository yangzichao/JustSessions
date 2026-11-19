import AppKit
import SwiftUI

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

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
