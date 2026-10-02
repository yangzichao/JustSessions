import AppKit
import SwiftUI

struct TranscriptSearchTextSurface: NSViewRepresentable {
    let text: NSAttributedString
    let selectedRange: NSRange?
    let navigationRevision: Int
    let reveal: ((NSTextView, NSRange) -> Bool)?

    func makeNSView(context: Context) -> TranscriptSearchTextView { TranscriptSearchTextView() }

    func updateNSView(_ view: TranscriptSearchTextView, context: Context) {
        if view.textStorage?.isEqual(to: text) != true {
            view.textStorage?.setAttributedString(text)
            view.invalidateIntrinsicContentSize()
        }
        view.selectedSearchRange = selectedRange
        view.navigationRevision = navigationRevision
        view.revealSelectedRange = reveal
        view.needsLayout = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TranscriptSearchTextView, context: Context) -> CGSize? {
        nsView.measuredSize(width: proposal.width)
    }
}
