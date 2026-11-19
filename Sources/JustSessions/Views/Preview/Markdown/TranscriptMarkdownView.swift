import SwiftUI

struct TranscriptMarkdownView: View {
    @Environment(\.transcriptReadingFontSize) private var fontSize
    private let markdown: PreparedTranscriptMarkdown

    /// Pages prepare their Markdown on the reader actor. A transcript built any other way is prepared here, before its
    /// first layout, so the message never changes height after the reader has restored a position.
    init(text: String, prepared: PreparedTranscriptMarkdown?) {
        markdown = prepared ?? PreparedTranscriptMarkdown(text: text)
    }

    private var blocks: [TranscriptMarkdownBlock] { markdown.blocks }
    private var segmentStarts: [Int: Int] { markdown.segmentStarts }

    var body: some View {
        Group {
            if let paragraph = singleParagraph {
                TranscriptTextBlock(source: paragraph, style: TranscriptTextStyle(fontSize: fontSize))
            } else {
                structuredBlocks
            }
        }
        .font(.system(size: fontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Plain messages need only one text view, keeping their lazy scroll measurements inexpensive and stable.
    private var singleParagraph: AttributedString? {
        guard blocks.count == 1, blocks[0].listDepth == 0, blocks[0].quoteDepth == 0,
            case .text(let text, nil) = blocks[0].content
        else { return nil }
        return text
    }

    private var structuredBlocks: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(blocks) { block in
                HStack(alignment: .top, spacing: 10) {
                    if block.quoteDepth > 0 {
                        Capsule().fill(ThemePalette.hairline).frame(width: 3)
                    }
                    if block.listDepth > 0 {
                        Text(block.listMarker ?? "")
                            .foregroundStyle(ThemePalette.secondaryText)
                            .frame(minWidth: 18, alignment: .trailing)
                    }
                    blockContent(block, segmentIndex: segmentStarts[block.id] ?? 0)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.leading, CGFloat(max(0, block.listDepth - 1)) * 20)
            }
        }
    }

    @ViewBuilder
    private func blockContent(_ block: TranscriptMarkdownBlock, segmentIndex: Int) -> some View {
        switch block.content {
        case .text(let text, let headingLevel):
            TranscriptTextBlock(
                source: text, segmentIndex: segmentIndex,
                style: TranscriptTextStyle(fontSize: headingLevel.map(headingFontSize) ?? fontSize, isSemibold: headingLevel != nil),
                copyRole: copyRole(of: block)
            )
        case .code(let text, let language):
            TranscriptCodeBlock(text: text, language: language, segmentIndex: segmentIndex)
        case .table(let table):
            TranscriptMarkdownTableView(table: table, segmentIndex: segmentIndex, indentation: indentation(of: block))
        case .divider:
            ThemeDivider().padding(.vertical, 4)
        }
    }

    /// The room `structuredBlocks` gives a block's quote bar and list marker, with the spacing after each, and its depth.
    private func indentation(of block: TranscriptMarkdownBlock) -> CGFloat {
        (block.quoteDepth > 0 ? 3 + 10 : 0) + (block.listDepth > 0 ? 18 + 10 : 0) + CGFloat(max(0, block.listDepth - 1)) * 20
    }

    /// A list item copies with its marker, indented by its depth; a later paragraph of the item, without a marker, lines
    /// up under the first.
    private func copyRole(of block: TranscriptMarkdownBlock) -> TranscriptTextCopyRole {
        guard block.listDepth > 0 else { return .paragraph }
        let indentation = String(repeating: "  ", count: block.listDepth - 1)
        return .listItem(marker: indentation + (block.listMarker ?? " "))
    }

    private func headingFontSize(_ level: Int) -> CGFloat {
        fontSize + (level == 1 ? 9 : level == 2 ? 5 : 2)
    }
}
