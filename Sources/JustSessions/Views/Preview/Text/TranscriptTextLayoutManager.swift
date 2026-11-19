import AppKit

/// AppKit draws a text view's selection in the accent only while that view is the window's first responder, and in
/// gray otherwise.
final class TranscriptTextLayoutManager: NSLayoutManager {
    var lineHeightPadding: CGFloat = 0

    override init() {
        super.init()
        delegate = self
    }

    required init?(coder: NSCoder) { nil }

    override func fillBackgroundRectArray(
        _ rectArray: UnsafePointer<NSRect>, count rectCount: Int, forCharacterRange charRange: NSRange, color: NSColor
    ) {
        // AppKit draws text on the main thread.
        let textView = firstTextView as? TranscriptTextView
        let drawsEmphasized = MainActor.assumeIsolated { textView?.drawsSelectionEmphasized == true }
        guard Self.isInactiveSelectionColor(color), drawsEmphasized else {
            super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: color)
            return
        }
        // The fill uses the graphics context's current color, which AppKit sets to `color` before calling this.
        NSColor.selectedTextBackgroundColor.setFill()
        super.fillBackgroundRectArray(rectArray, count: rectCount, forCharacterRange: charRange, color: .selectedTextBackgroundColor)
    }

    static func isInactiveSelectionColor(_ color: NSColor) -> Bool {
        color == .unemphasizedSelectedContentBackgroundColor || color == .unemphasizedSelectedTextBackgroundColor
    }
}
