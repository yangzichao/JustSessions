import AppKit

/// SwiftUI sets the system font's lines up to a point taller than TextKit does at some sizes, such as 15 pt, the
/// default reading size, and puts the extra space below each line.
extension TranscriptTextLayoutManager: NSLayoutManagerDelegate {
    /// String drawing measures a line as SwiftUI does.
    func lineHeightPadding(for font: NSFont) -> CGFloat {
        max(0, NSAttributedString(string: "x", attributes: [.font: font]).size().height - defaultLineHeight(for: font))
    }

    func layoutManager(
        _ layoutManager: NSLayoutManager, shouldSetLineFragmentRect lineFragmentRect: UnsafeMutablePointer<NSRect>,
        lineFragmentUsedRect: UnsafeMutablePointer<NSRect>, baselineOffset: UnsafeMutablePointer<CGFloat>,
        in textContainer: NSTextContainer, forGlyphRange glyphRange: NSRange
    ) -> Bool {
        guard lineHeightPadding > 0 else { return false }
        lineFragmentRect.pointee.size.height += lineHeightPadding
        lineFragmentUsedRect.pointee.size.height += lineHeightPadding
        return true
    }
}
