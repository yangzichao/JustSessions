import SwiftUI

/// One block of transcript text: a message, a paragraph, a heading, a list item, a code block, a table cell, a tool
/// summary, or a note. Each is an AppKit text view, so a selection can run across blocks and Find can locate a match.
struct TranscriptTextBlock: View {
    let source: AttributedString
    /// The block's place among its entry's text blocks, as `TranscriptSearchSegments` numbers them.
    var segmentIndex = 0
    let style: TranscriptTextStyle
    var copyRole: TranscriptTextCopyRole = .paragraph
    @Environment(\.transcriptSearchContext) private var searchContext
    @Environment(\.transcriptSearchEntryIndex) private var entryIndex
    @Environment(\.transcriptTextColors) private var colors
    @Environment(\.transcriptTextSelection) private var selectionCoordinator

    var body: some View {
        // Every text block in the transcript runs this body when Find's context changes, so it searches, and copies its
        // text to do so, only while Find has a query.
        let matchRanges = searchContext.query.isEmpty ? [] : TranscriptTextSearch.ranges(of: searchContext.query, in: source.plainText)
        let selectedMatchRange = selectedMatchRange.flatMap { matchRanges.contains($0) ? $0 : nil }
        TranscriptTextSurface(
            content: TranscriptTextContent(
                source: source, style: style, colors: colors, matchRanges: matchRanges, selectedMatchRange: selectedMatchRange
            ),
            selectionKey: TranscriptTextSelectionKey(entryIndex: entryIndex, segmentIndex: segmentIndex),
            copyRole: copyRole,
            navigationRevision: selectedMatchRange == nil ? 0 : searchContext.navigationRevision,
            positionController: searchContext.positionController,
            selectionCoordinator: selectionCoordinator
        )
        .equatable()
    }

    private var selectedMatchRange: NSRange? {
        guard let match = searchContext.selectedMatch, match.entryIndex == entryIndex, match.segmentIndex == segmentIndex else {
            return nil
        }
        return match.range
    }
}

extension EnvironmentValues {
    /// The reader's text colors, resolved once for all its blocks in the window's theme and appearance.
    @Entry var transcriptTextColors = TranscriptTextColors(theme: ResolvedAppTheme(.justSessions), isDark: false)
}
