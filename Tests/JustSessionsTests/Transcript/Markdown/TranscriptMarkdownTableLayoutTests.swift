import AppKit
import SwiftUI
import Testing

@testable import JustSessions

/// A Markdown table in the reader (RDR-04): columns as wide as their widest cells while the table fits the reader's
/// column, the widest cut to fit it otherwise, and each row as tall as its wrapped cells.
@MainActor
struct TranscriptMarkdownTableLayoutTests {
    private static func columnWidths(_ ideal: [CGFloat], available: CGFloat, minimums: [CGFloat]? = nil) -> [CGFloat] {
        TranscriptMarkdownTableLayout.columnWidths(
            idealWidths: ideal, minimumWidths: minimums ?? ideal.map { _ in 120 },
            availableWidth: available)
    }

    @Test func columnsThatFitKeepTheirWidths() {
        #expect(Self.columnWidths([110.2, 300], available: 760) == [111, 300])
    }

    /// The release record's table: a short label column and a long one that takes the rest.
    @Test func theWidestColumnGivesUpWidthFirst() {
        #expect(Self.columnWidths([140, 1_900], available: 760) == [140, 620])
        #expect(Self.columnWidths([140, 500, 900], available: 760) == [140, 310, 310])
        #expect(Self.columnWidths([80, 200, 900, 900], available: 760) == [80, 200, 240, 240])
    }

    @Test func noColumnIsCutBelowTheMinimumSoAVeryWideTableScrolls() {
        let widths = Self.columnWidths(Array(repeating: 400, count: 8), available: 760)

        #expect(widths == Array(repeating: 120, count: 8))
        #expect(Self.columnWidths([60, 400, 400, 400, 400, 400, 400], available: 760) == [60] + Array(repeating: 120, count: 6))
    }

    /// A column whose longest word is wider than the minimum keeps that width, so no word breaks.
    @Test func aColumnIsNeverCutBelowItsLongestWord() {
        #expect(Self.columnWidths([300, 900, 900], available: 600, minimums: [180, 120, 120]) == [200, 200, 200])
        #expect(Self.columnWidths([300, 900, 900], available: 480, minimums: [180, 120, 120]) == [180, 150, 150])
        #expect(
            Self.columnWidths([300, 900, 900, 900, 900], available: 600, minimums: [180, 120, 120, 120, 120])
                == [180, 120, 120, 120, 120])
    }

    private static func table(_ rows: [[String]]) -> TranscriptMarkdownTable {
        TranscriptMarkdownTable(
            rows: rows.enumerated().map { index, cells in
                TranscriptMarkdownTable.Row(id: index, isHeader: index == 0, cells: cells.map { AttributedString($0) })
            })
    }

    private static func size(of table: TranscriptMarkdownTable, columnWidth: CGFloat = 760) -> CGSize {
        let view = TranscriptMarkdownTableView(table: table)
            .environment(\.transcriptColumnWidth, columnWidth)
            .frame(width: columnWidth, alignment: .leading)
        let host = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: columnWidth, height: 800), styleMask: [.borderless],
            backing: .buffered, defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    /// A cell's wrapped lines make its row taller; before, rows kept a single line's height and the lines ran into the
    /// rows below.
    @Test func aRowIsAsTallAsItsWrappedCell() {
        let long = String(repeating: "passed make release-check on this exact commit, with an editorial review. ", count: 6)
        let short = Self.size(of: Self.table([["", ""], ["Previous tag", "v1.2.17"], ["Tagged commit", "c0e5069b"]]))
        let wrapped = Self.size(of: Self.table([["", ""], ["Previous tag", "v1.2.17"], ["Tagged commit", long]]))

        #expect(wrapped.height > short.height + 60)
    }

    @Test func aTableUsesTheReadersColumnBeforeWrapping() throws {
        let long = String(repeating: "word ", count: 120)
        let narrow = Self.size(of: Self.table([["Name", "Value"], ["Previous tag", "v1.2.17"]]))
        let wide = Self.size(of: Self.table([["Name", "Value"], ["Notes", long]]))
        let tall = Self.size(of: Self.table([["Name", "Value"], ["Notes", long]]), columnWidth: 500)

        #expect(narrow.height < 120)
        #expect(wide.height > narrow.height)
        #expect(tall.height > wide.height + 40)
    }
}
