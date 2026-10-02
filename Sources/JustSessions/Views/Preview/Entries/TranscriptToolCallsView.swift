import SwiftUI

/// Tools stay behind a compact disclosure, including runs with only one call.
struct TranscriptToolCallsView: View {
    let summaries: [String]
    @State private var isExpanded = false
    @Environment(\.transcriptSearchContext) private var searchContext
    @Environment(\.transcriptSearchEntryIndex) private var entryIndex

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(summaries.enumerated()), id: \.offset) { segmentIndex, summary in
                    TranscriptSearchableText(source: AttributedString(summary), segmentIndex: segmentIndex, fontSize: 12, isMonospaced: true, isSecondary: true)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 8)
        } label: {
            Label(summaries.count == 1 ? "1 tool call" : "\(summaries.count) tool calls", systemImage: "wrench.and.screwdriver")
                .font(.system(size: 12))
        }
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
        .onAppear(perform: revealMatchingTool)
        .onChange(of: searchContext.selectedMatch) { revealMatchingTool() }
    }

    private func revealMatchingTool() {
        if searchContext.selectedMatch?.entryIndex == entryIndex { isExpanded = true }
    }
}
