import AppKit

struct TranscriptTextContent: Equatable {
    let source: AttributedString
    let style: TranscriptTextStyle
    let colors: TranscriptTextColors
    var matchRanges: [NSRange] = []
    var selectedMatchRange: NSRange?

    func attributedString() -> NSAttributedString {
        TranscriptAttributedText.make(
            source: source, font: style.font, lineSpacing: style.lineSpacing,
            foreground: colors.foreground(for: style.tone), link: colors.link, highlight: colors.matchHighlight,
            selectedForeground: colors.selectedMatchForeground, ranges: matchRanges, selectedRange: selectedMatchRange
        )
    }
}

enum TranscriptAttributedText {
    static func make(
        source: AttributedString, font: NSFont, lineSpacing: CGFloat,
        foreground: NSColor, link linkColor: NSColor, highlight: NSColor, selectedForeground: NSColor,
        ranges: [NSRange], selectedRange: NSRange?
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        let text = NSMutableAttributedString(
            string: source.plainText,
            attributes: [
                .font: font, .foregroundColor: foreground, .paragraphStyle: paragraphStyle,
            ])
        for run in source.runs {
            let range = NSRange(run.range, in: source)
            var runFont = font
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) { runFont = .monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular) }
                if intent.contains(.stronglyEmphasized) { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask) }
                if intent.contains(.emphasized) { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask) }
                if intent.contains(.strikethrough) {
                    text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
                }
            }
            text.addAttribute(.font, value: runFont, range: range)
            if let link = run.link {
                // Colored here as well as by the text view's link attributes, which a view drawn offscreen leaves out.
                text.addAttributes([.link: link, .foregroundColor: linkColor], range: range)
            }
        }
        for range in ranges {
            let isSelected = range == selectedRange
            text.addAttribute(.backgroundColor, value: isSelected ? highlight : highlight.withAlphaComponent(0.18), range: range)
            if isSelected { text.addAttribute(.foregroundColor, value: selectedForeground, range: range) }
        }
        return text
    }
}
