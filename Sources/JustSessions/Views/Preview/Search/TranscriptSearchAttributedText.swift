import AppKit
import SwiftUI

enum TranscriptSearchAttributedText {
    static func make(
        source: AttributedString, font: NSFont, lineSpacing: CGFloat,
        foreground: NSColor, highlight: NSColor, selectedForeground: NSColor,
        ranges: [NSRange], selectedRange: NSRange?
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        let text = NSMutableAttributedString(string: String(source.characters), attributes: [
            .font: font, .foregroundColor: foreground, .paragraphStyle: paragraphStyle,
        ])
        for run in source.runs {
            let offset = String(source[source.startIndex..<run.range.lowerBound].characters).utf16.count
            let range = NSRange(location: offset, length: String(source[run.range].characters).utf16.count)
            var runFont = font
            if let intent = run.inlinePresentationIntent {
                if intent.contains(.code) { runFont = .monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular) }
                if intent.contains(.stronglyEmphasized) { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask) }
                if intent.contains(.emphasized) { runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask) }
                if intent.contains(.strikethrough) { text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range) }
            }
            text.addAttribute(.font, value: runFont, range: range)
            if let link = run.link { text.addAttribute(.link, value: link, range: range) }
        }
        for range in ranges {
            let isSelected = range == selectedRange
            text.addAttribute(.backgroundColor, value: isSelected ? highlight : highlight.withAlphaComponent(0.18), range: range)
            if isSelected { text.addAttribute(.foregroundColor, value: selectedForeground, range: range) }
        }
        return text
    }

    static func color(_ themeColor: ThemeColor, in environment: EnvironmentValues) -> NSColor {
        let resolved = themeColor.resolve(in: environment)
        return NSColor(srgbRed: CGFloat(resolved.red), green: CGFloat(resolved.green), blue: CGFloat(resolved.blue), alpha: CGFloat(resolved.opacity))
    }
}
