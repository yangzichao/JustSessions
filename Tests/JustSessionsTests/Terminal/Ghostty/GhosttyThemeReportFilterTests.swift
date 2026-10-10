import Foundation
import Testing
@testable import JustSessions

struct GhosttyThemeReportFilterTests {
    @Test func ghosttysOwnThemeReportsAreRemoved() {
        #expect(filtered("\u{1B}[?997;2n") == "")
        #expect(filtered("\u{1B}[?997;1n") == "")
        #expect(filtered("\u{1B}[?997;2n\u{1B}[?997;2n") == "")
    }

    @Test func whatSurroundsAReportIsKept() {
        #expect(filtered("\u{1B}[?62;22c\u{1B}[?997;1nab") == "\u{1B}[?62;22cab")
        #expect(filtered("\u{1B}]11;rgb:1010/2020/3030\u{1B}\\\u{1B}[?997;2n") == "\u{1B}]11;rgb:1010/2020/3030\u{1B}\\")
    }

    @Test func otherBytesPassUnchanged() {
        for text in ["", "a", "\u{1B}", "\u{1B}[", "\u{1B}[?997;3n", "\u{1B}[?997;1", "\u{1B}[13;2u\r", "你好\u{1B}[A"] {
            #expect(filtered(text) == text)
        }
    }

    /// A report split across writes stays as it is, rather than holding back an Escape key for the next write.
    @Test func partOfAReportIsNeverHeldBack() {
        #expect(filtered("\u{1B}") == "\u{1B}")
        #expect(filtered("\u{1B}[?997;") == "\u{1B}[?997;")
        #expect(filtered("2n") == "2n")
    }

    private func filtered(_ text: String) -> String {
        String(decoding: GhosttyThemeReportFilter.removingThemeReports(from: Data(text.utf8)), as: UTF8.self)
    }
}
