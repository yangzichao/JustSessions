import AppKit
import SwiftUI

/// Keep the usual SwiftUI rendering outside Find, and use native range geometry only for matching text.
struct TranscriptSearchableText: View {
    let source: AttributedString
    var segmentIndex = 0
    let fontSize: CGFloat
    var isMonospaced = false
    var isSemibold = false
    var lineSpacing: CGFloat = 4
    var isSecondary = false
    @Environment(\.transcriptSearchContext) private var searchContext

    var body: some View {
        // Every text block in the transcript runs this body, so it searches, and copies its text to do so, only during Find.
        let ranges = searchContext.query.isEmpty ? [] : TranscriptTextSearch.ranges(of: searchContext.query, in: source.plainText)
        if ranges.isEmpty {
            Text(source)
        } else {
            TranscriptSearchMatchesText(
                source: source, ranges: ranges, segmentIndex: segmentIndex, fontSize: fontSize, isMonospaced: isMonospaced,
                isSemibold: isSemibold, lineSpacing: lineSpacing, isSecondary: isSecondary
            )
        }
    }
}

/// A text block with Find's matches highlighted. It alone reads the whole environment, to resolve theme colors, so an
/// environment change does not rerun every text block in the transcript.
private struct TranscriptSearchMatchesText: View {
    let source: AttributedString
    let ranges: [NSRange]
    let segmentIndex: Int
    let fontSize: CGFloat
    let isMonospaced: Bool
    let isSemibold: Bool
    let lineSpacing: CGFloat
    let isSecondary: Bool
    @Environment(\.self) private var environment
    @Environment(\.transcriptSearchContext) private var searchContext
    @Environment(\.transcriptSearchEntryIndex) private var entryIndex

    var body: some View {
        let selectedRange = selectedRange.flatMap { ranges.contains($0) ? $0 : nil }
        TranscriptSearchTextSurface(
            text: TranscriptSearchAttributedText.make(
                source: source, font: font, lineSpacing: lineSpacing,
                foreground: TranscriptSearchAttributedText.color(isSecondary ? ThemePalette.secondaryText : ThemePalette.ink, in: environment),
                highlight: TranscriptSearchAttributedText.color(ThemePalette.ink, in: environment),
                selectedForeground: TranscriptSearchAttributedText.color(ThemePalette.inkForeground, in: environment),
                ranges: ranges, selectedRange: selectedRange
            ),
            selectedRange: selectedRange,
            navigationRevision: searchContext.navigationRevision,
            reveal: { view, range in
                searchContext.positionController?.revealSearchMatch(in: view, range: range, entryIndex: entryIndex) ?? false
            }
        )
    }

    private var selectedRange: NSRange? {
        guard let match = searchContext.selectedMatch, match.entryIndex == entryIndex, match.segmentIndex == segmentIndex else { return nil }
        return match.range
    }

    private var font: NSFont {
        let weight: NSFont.Weight = isSemibold ? .semibold : .regular
        return isMonospaced ? .monospacedSystemFont(ofSize: fontSize, weight: weight) : .systemFont(ofSize: fontSize, weight: weight)
    }
}
