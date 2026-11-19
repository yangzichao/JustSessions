import Testing

@testable import JustSessions

/// A screen row's text measured in cells; see `TerminalScreenRow`.
struct TerminalScreenRowTests {
    @Test func wideCharactersTakeTwoCells() {
        let row = TerminalScreenRow("说明：ok  ")

        #expect(row.textWidth == 8)
        #expect(row.characterIndex(atColumn: 1) == 0)
        #expect(row.characterIndex(atColumn: 5) == 2)
        #expect(row.characterIndex(atColumn: 6) == 3)
    }

    @Test func emojiDrawnAsPicturesTakeTwoCells() {
        #expect(TerminalScreenRow("✅ ok").textWidth == 5)
        #expect(TerminalScreenRow("⚠️ ok").textWidth == 5)
    }

    /// A prompt's text in a row starts at the cell its CLI keeps for it, after a marker such as `❯`.
    @Test func textFromAColumnSkipsWhatComesBefore() {
        let row = TerminalScreenRow("❯ 你好 kiwi   ")

        #expect(row.text(fromColumn: 2) == ("你好 kiwi", 9))
        #expect(row.text(fromColumn: 20) == ("", 0))
        #expect(row.character(atColumn: 3) == "你")
        #expect(TerminalScreenRow("  kiwi").isBlank(beforeColumn: 2))
        #expect(!row.isBlank(beforeColumn: 2))
    }

    @Test func wordsSkipIndentation() {
        let row = TerminalScreenRow("  first middle last ")

        #expect(row.firstWordRange.map { String(row.characters[$0]) } == "first")
        #expect(row.lastWordRange.map { String(row.characters[$0]) } == "last")
        #expect(row.wordRange(around: 1) == nil)
    }
}
