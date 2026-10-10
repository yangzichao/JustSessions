import Testing
@testable import JustSessions

/// Where Ghostty's answer to a background query ends in what it sends the tab's process, so an owed theme report can
/// follow it.
struct GhosttyBackgroundColorAnswerTests {
    @Test(arguments: ["\u{07}", "\u{1B}\\"])
    func theAnswerEndsAfterItsTerminator(terminator: String) {
        let answer = "\u{1B}]11;rgb:1a1a/1b1b/2626" + terminator

        #expect(endIndex(in: answer) == answer.utf8.count)
        #expect(endIndex(in: "\u{1B}]10;rgb:0000/0000/0000\u{07}" + answer + "typed") == ("\u{1B}]10;rgb:0000/0000/0000\u{07}" + answer).utf8.count)
    }

    @Test func otherRepliesAndUnendedAnswersAreNoAnswer() {
        // Palette color 11, the foreground, and a background color query typed as text.
        #expect(endIndex(in: "\u{1B}]4;11;rgb:ffff/0000/0000\u{07}") == nil)
        #expect(endIndex(in: "\u{1B}]10;rgb:ffff/ffff/ffff\u{1B}\\") == nil)
        #expect(endIndex(in: "]11;rgb:ffff/ffff/ffff\u{07}") == nil)
        #expect(endIndex(in: "\u{1B}]11;rgb:ffff/ffff/ffff") == nil)
        // An escape that starts another sequence ends the command without answering.
        #expect(endIndex(in: "\u{1B}]11;rgb:ffff\u{1B}[A\u{07}") == nil)
    }

    private func endIndex(in text: String) -> Int? {
        GhosttyBackgroundColorAnswer.endIndex(in: Array(text.utf8))
    }
}
