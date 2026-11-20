import SwiftUI

struct TranscriptToolCallsView: View {
    let summaries: [String]
    @State private var isExpanded = false
    @Environment(\.transcriptSearchContext) private var searchContext
    @Environment(\.transcriptSearchEntryIndex) private var entryIndex
    @Environment(\.transcriptReadingFontSize) private var readingFontSize

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(summaries.enumerated()), id: \.offset) { segmentIndex, summary in
                    TranscriptTextBlock(
                        source: AttributedString(summary), segmentIndex: segmentIndex,
                        style: TranscriptTextStyle(
                            fontSize: TranscriptReadingTextSize.toolCallSummarySize(forReadingSize: readingFontSize), isMonospaced: true,
                            lineSpacing: 0, tone: .secondary),
                        copyRole: .line
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        } label: {
            ThemeDisclosureTitleButton(isExpanded: $isExpanded) {
                Label(summaries.count == 1 ? "1 tool call" : "\(summaries.count) tool calls", systemImage: "wrench.and.screwdriver")
                    .font(ThemeFont.callout)
            }
        }
        .foregroundStyle(ThemePalette.secondaryText)
        .padding(.vertical, 4)
        .onAppear(perform: revealMatchingTool)
        .onChange(of: searchContext.selectedMatch) { revealMatchingTool() }
    }

    private func revealMatchingTool() {
        if searchContext.selectedMatch?.entryIndex == entryIndex { isExpanded = true }
    }
}
