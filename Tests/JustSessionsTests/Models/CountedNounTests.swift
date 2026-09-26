import Testing
@testable import JustSessions

struct CountedNounTests {
    @Test(arguments: [(0, "0 sessions"), (1, "1 session"), (2, "2 sessions"), (11, "11 sessions")])
    func countsSessions(count: Int, expectedPhrase: String) {
        #expect(CountedNoun.phrase(count: count, singular: "session") == expectedPhrase)
    }

    @Test func usesTheGivenPluralForIrregularNouns() {
        #expect(CountedNoun.phrase(count: 1, singular: "match", plural: "matches") == "1 match")
        #expect(CountedNoun.phrase(count: 3, singular: "match", plural: "matches") == "3 matches")
    }
}
