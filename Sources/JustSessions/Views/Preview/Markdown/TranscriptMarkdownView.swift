import SwiftUI

struct TranscriptMarkdownView: View {
    @Environment(\.transcriptReadingFontSize) private var fontSize
    private let blocks: [TranscriptMarkdownBlock]

    init(text: String) {
        blocks = TranscriptMarkdownParser.blocks(from: text)
    }

    var body: some View {
        Group {
            if let paragraph = singleParagraph {
                Text(TranscriptReadingTypography.inlineText(paragraph, fontSize: fontSize))
                    .textSelection(.enabled)
            } else {
                structuredBlocks
            }
        }
        .font(.system(size: fontSize))
        .lineSpacing(4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Plain messages need only one text view, keeping their lazy scroll measurements inexpensive and stable.
    private var singleParagraph: AttributedString? {
        guard blocks.count == 1, blocks[0].listDepth == 0, blocks[0].quoteDepth == 0,
              case .text(let text, nil) = blocks[0].content else { return nil }
        return text
    }

    private var structuredBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                HStack(alignment: .top, spacing: 10) {
                    if block.quoteDepth > 0 {
                        RoundedRectangle(cornerRadius: 2).fill(ThemePalette.hairline).frame(width: 3)
                    }
                    if block.listDepth > 0 {
                        Text(block.listMarker ?? "")
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 18, alignment: .trailing)
                    }
                    blockContent(block.content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 20)
            }
        }
    }

    @ViewBuilder
    private func blockContent(_ content: TranscriptMarkdownBlock.Content) -> some View {
        switch content {
        case .text(let text, let headingLevel):
            Text(TranscriptReadingTypography.inlineText(text, fontSize: fontSize))
                .font(headingLevel.map { .system(size: headingFontSize($0), weight: .semibold) } ?? .system(size: fontSize))
                .textSelection(.enabled)
        case .code(let text, let language):
            TranscriptCodeBlock(text: text, language: language)
        case .table(let table):
            TranscriptMarkdownTableView(table: table)
        case .divider:
            ThemeDivider().padding(.vertical, 4)
        }
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        fontSize + (level == 1 ? 9 : level == 2 ? 5 : 2)
    }
}
