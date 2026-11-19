import AppKit
import SwiftUI

struct ResizeCursorRegion: NSViewRepresentable {
    var betweenRows = false

    func makeNSView(context: Context) -> ResizeCursorRegionView {
        ResizeCursorRegionView()
    }

    func updateNSView(_ nsView: ResizeCursorRegionView, context: Context) {
        nsView.betweenRows = betweenRows
    }
}

final class ResizeCursorRegionView: NSView {
    var betweenRows = false {
        didSet { if betweenRows != oldValue { window?.invalidateCursorRects(for: self) } }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: betweenRows ? .resizeUpDown : .resizeLeftRight)
    }

    override func layout() {
        super.layout()
        window?.invalidateCursorRects(for: self)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
