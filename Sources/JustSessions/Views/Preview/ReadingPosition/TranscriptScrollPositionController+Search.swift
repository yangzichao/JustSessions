import AppKit

extension TranscriptScrollPositionController {
    /// Reveal both axes: code and tables can have their own horizontal scroll view inside the conversation.
    func revealSearchMatch(in textView: NSTextView, range: NSRange, entryIndex: Int) -> Bool {
        guard let scrollView, let marker = entryMarkers.object(forKey: NSNumber(value: entryIndex)),
              marker.bounds.height > 0, textView.window != nil,
              let textContainer = textView.textContainer, let layoutManager = textView.layoutManager else { return false }
        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var matchRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        matchRect.origin.x += textView.textContainerOrigin.x
        matchRect.origin.y += textView.textContainerOrigin.y
        guard matchRect.height > 0 else { return false }

        var ancestor = textView.superview
        while let view = ancestor {
            if let horizontalScrollView = view as? NSScrollView, horizontalScrollView !== scrollView {
                let horizontalClipView = horizontalScrollView.contentView
                let rectangle = textView.convert(matchRect, to: horizontalClipView)
                if !horizontalClipView.bounds.contains(rectangle) { horizontalClipView.scrollToVisible(rectangle) }
            }
            ancestor = view.superview
        }
        let clipView = scrollView.contentView
        let matchFrame = textView.convert(matchRect, to: clipView)
        let entryFrame = marker.convert(marker.bounds, to: clipView)
        restore(.entry(index: entryIndex, offset: max(-6, matchFrame.minY - entryFrame.minY - 60)))
        return true
    }
}
