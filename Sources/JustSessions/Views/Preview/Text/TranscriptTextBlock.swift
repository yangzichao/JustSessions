import SwiftUI

struct TranscriptTextBlock: View {
    let source: AttributedString
    var segmentIndex = 0
    let style: TranscriptTextStyle
    var copyRole: TranscriptTextCopyRole = .paragraph
    @Environment(\.transcriptSearchContext) private var searchContext
    @Environment(\.transcriptSearchEntryIndex) private var entryIndex
    @Environment(\.transcriptTextColors) private var colors
    @Environment(\.transcriptTextSelection) private var selectionCoordinator

    var body: some View {
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
    @Entry var transcriptTextColors = TranscriptTextColors(theme: ResolvedAppTheme(.justSessions), isDark: false)
}
