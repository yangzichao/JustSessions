import Testing

@testable import JustSessions

struct JoinedWordLinkTests {
    @Test func aURLInBracketsLeavesThemOut() {
        #expect(link(in: "(https://example.com/x)", holding: 5) == "https://example.com/x")
    }

    @Test func aURLKeepsTheBracketItOpenedButNotTheCommaAfterIt() {
        #expect(
            link(in: "https://en.wikipedia.org/wiki/Swift_(language),", holding: 5)
                == "https://en.wikipedia.org/wiki/Swift_(language)")
    }

    @Test func aPathKeepsItsLineNumberButNotTheColonAfterIt() {
        #expect(link(in: "Sources/App/main.swift:42:", holding: 3) == "Sources/App/main.swift:42")
    }

    @Test func aWordWithoutASlashIsNoPath() {
        #expect(link(in: "main.swift:42", holding: 3) == nil)
    }

    @Test func textBeforeTheSchemeIsLeftOut() {
        #expect(link(in: "说明：https://example.com/x", holding: 1) == nil)
        #expect(link(in: "说明：https://example.com/x", holding: 8) == "https://example.com/x")
    }

    private func link(in word: String, holding index: Int) -> String? {
        let characters = Array(word)
        return JoinedWordLink.linkRange(in: characters, holding: index).map { String(characters[$0]) }
    }
}
