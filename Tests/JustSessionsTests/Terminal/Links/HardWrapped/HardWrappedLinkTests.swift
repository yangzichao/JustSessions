import Testing

@testable import JustSessions

/// A link a CLI broke over rows, found from the screen's text; see `HardWrappedLink`. Unless a test says otherwise,
/// the screen is as wide as its first row.
struct HardWrappedLinkTests {
    /// As Claude Code shows a URL in a reply: to the last column, then on after a two-space indent.
    private static let replyRows = [
        "* See https://example.com/docs/getting",
        "  -started/install for the steps.",
    ]

    @Test func clickingTheFirstRowOfABrokenURLFindsAllOfIt() {
        #expect(link(in: Self.replyRows, row: 0, column: 10) == "https://example.com/docs/getting-started/install")
    }

    @Test func clickingTheSecondRowOfABrokenURLFindsAllOfIt() {
        #expect(link(in: Self.replyRows, row: 1, column: 5) == "https://example.com/docs/getting-started/install")
    }

    @Test func aURLOverThreeRowsIsFoundFromTheMiddleOne() {
        let rows = [
            "* https://example.com/a",
            "  bcdefghijklmnopqrstu",
            "  vwx and more",
        ]

        #expect(link(in: rows, row: 1, column: 5) == "https://example.com/abcdefghijklmnopqrstuvwx")
    }

    /// Claude Code's echo of a prompt stops a column short of the edge, which it keeps for padding.
    @Test func aRowEndingOneColumnShortOfTheEdgeGoesOn() {
        let rows = [
            "> open https://example.com/very/long/pa",
            "  th/to/page please",
        ]

        #expect(
            link(in: rows, columns: rows[0].count + 1, row: 0, column: 10)
                == "https://example.com/very/long/path/to/page")
    }

    @Test func aRowEndingShortOfTheEdgeEndsTheLink() {
        let rows = [
            "* https://example.com/docs",
            "  more text",
        ]

        #expect(link(in: rows, columns: 40, row: 0, column: 5) == nil)
    }

    @Test func aLinkBeforeTheRowsLastWordIsLeftToTheEngine() {
        let rows = [
            "https://example.com/a and then words to",
            "  edge",
        ]

        #expect(link(in: rows, row: 0, column: 5) == nil)
    }

    @Test func aPlainWordBesideABrokenURLIsNoLink() {
        #expect(link(in: Self.replyRows, row: 0, column: 3) == nil)
    }

    /// Chinese characters take two cells each, so the row reaches the edge with fewer characters than columns.
    @Test func wideCharactersBeforeTheURLCountTwoCells() {
        let rows = [
            "说明：https://example.com/docs/get",
            "  ting-started",
        ]

        #expect(link(in: rows, columns: 34, row: 0, column: 10) == "https://example.com/docs/getting-started")
    }

    /// As Claude Code shows a path in a tool's output.
    @Test func aBrokenPathIsFoundWithItsLineNumber() {
        let rows = [
            "Edited Sources/JustSessions/Services/Ter",
            "  minal/Links/Opener.swift:42 to fix it",
        ]

        #expect(link(in: rows, row: 1, column: 4) == "Sources/JustSessions/Services/Terminal/Links/Opener.swift:42")
    }

    @Test func theSentencesFullStopIsNotPartOfTheURL() {
        let rows = [
            "See https://example.com/docs/getting-st",
            "  arted.",
        ]

        #expect(link(in: rows, row: 0, column: 6) == "https://example.com/docs/getting-started")
    }

    @Test func anEngineLinkTheRowDoesNotShowWins() throws {
        let link = try #require(HardWrappedLink(rows: Self.replyRows, columns: Self.replyRows[0].count, row: 0, column: 10))

        #expect(link.resolved(engineLink: "https://example.com/target") == "https://example.com/target")
        #expect(link.resolved(engineLink: "https://example.com/docs/getting") == link.text)
        #expect(link.resolved(engineLink: nil) == link.text)
    }

    private func link(in rows: [String], columns: Int? = nil, row: Int, column: Int) -> String? {
        HardWrappedLink(rows: rows, columns: columns ?? rows[0].count, row: row, column: column)?.text
    }
}
