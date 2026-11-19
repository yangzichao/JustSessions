import Testing

@testable import JustSessions

struct EndedTabScreenTextTests {
    @Test func keepsTheRowsWithTextWithoutTrailingSpaces() {
        let rows = ["", "protocol version mismatch (client 8, server 7)   ", "", "Connection to devbox closed.  ", "", ""]
        #expect(
            EndedTabScreenText.text(ofRows: rows)
                == "protocol version mismatch (client 8, server 7)\n\nConnection to devbox closed.")
    }

    @Test func aBlankScreenShowsNothing() {
        #expect(EndedTabScreenText.text(ofRows: ["", "   "]) == nil)
    }

    @Test func keepsOnlyTheLastLinesAndCharacters() throws {
        let rows = (1...100).map { "line \($0)" }
        let lines = try #require(EndedTabScreenText.text(ofRows: rows)).split(separator: "\n")
        #expect(lines.count == EndedTabScreenText.maximumLineCount)
        #expect(lines.last == "line 100")

        let wideRows = Array(repeating: String(repeating: "x", count: 200), count: 40)
        #expect(EndedTabScreenText.text(ofRows: wideRows)?.count == EndedTabScreenText.maximumCharacterCount)
    }
}
