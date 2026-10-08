import Testing
@testable import JustSessions

struct TerminalFileDropPasteTests {
    @Test func plainPathIsTypedAsItIs() {
        #expect(TerminalFileDropPaste.escapedPath("/Users/me/notes/plan-v2_final.md") == "/Users/me/notes/plan-v2_final.md")
    }

    @Test func charactersAShellReadsSpeciallyGetABackslash() {
        #expect(
            TerminalFileDropPaste.escapedPath("/Users/me/My Files/it's (1) & $HOME*.png")
                == #"/Users/me/My\ Files/it\'s\ \(1\)\ \&\ \$HOME\*.png"#
        )
    }

    @Test func nonASCIICharactersStayAsTheyAre() {
        let screenshotPath = "/Users/me/Desktop/截图 2026-10-08 at 3.14.15\u{202F}PM.png"

        #expect(
            TerminalFileDropPaste.escapedPath(screenshotPath)
                == "/Users/me/Desktop/截图\\ 2026-10-08\\ at\\ 3.14.15\u{202F}PM.png"
        )
    }

    @Test func eachPathIsItsOwnBracketedPasteWhenTheProgramAskedForThem() {
        let bytes = TerminalFileDropPaste.bytes(forPaths: ["/tmp/a b.png", "/tmp/c.png"], isBracketed: true)

        #expect(String(decoding: bytes, as: UTF8.self) == "\u{1B}[200~/tmp/a\\ b.png \u{1B}[201~\u{1B}[200~/tmp/c.png \u{1B}[201~")
    }

    @Test func pathsAreTypedSeparatedBySpacesWithoutBracketedPaste() {
        let bytes = TerminalFileDropPaste.bytes(forPaths: ["/tmp/a b.png", "/tmp/c.png"], isBracketed: false)

        #expect(String(decoding: bytes, as: UTF8.self) == "/tmp/a\\ b.png /tmp/c.png ")
    }
}
