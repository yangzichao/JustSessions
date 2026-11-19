import Foundation
import Testing

@testable import JustSessions

/// What Bookmarks → Show All Bookmarks… lists (RDR-52).
struct AllBookmarksListTests {
    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    private let older = Conversation.fixture(provider: .codex, sessionID: "older", updatedAt: Date(timeIntervalSince1970: 100))
    private let newer = Conversation.fixture(provider: .claude, sessionID: "newer", updatedAt: Date(timeIntervalSince1970: 200))

    /// Two listed sessions and one no host lists: the older one's `a` is labelled and tagged, the newer one's `a` tagged.
    private var bookmarks: MessageBookmarks {
        MessageBookmarks(bookmarksByConversationID: [
            older.id: [
                MessageBookmark(
                    letter: "a", entryID: id(1), kind: .user, snippet: "Ship the release", label: "Release day",
                    tags: ["deploy", "todo"]),
                MessageBookmark(letter: "b", entryID: id(4), kind: .assistant, snippet: "The tests pass"),
            ],
            newer.id: [MessageBookmark(letter: "a", entryID: id(2), kind: .assistant, snippet: "Use a feature flag", tags: ["Todo"])],
            "Codex:gone@removed-host": [MessageBookmark(letter: "a", entryID: id(1), kind: .user, snippet: "Elsewhere")],
        ])
    }

    private func list(_ typed: String = "", tags: Set<String> = []) -> AllBookmarksList {
        let listed = [older.id: older, newer.id: newer]
        return AllBookmarksList(
            bookmarks: bookmarks, query: MessageBookmarkQuery(typed), requiredTags: tags,
            conversation: { listed[$0] }, title: { $0.id == older.id ? "Release work" : "Flags" })
    }

    @Test func everyListedSessionShowsNewestFirstWithItsBookmarksInOrder() {
        let all = list()

        #expect(all.sections.map(\.conversation.id) == [newer.id, older.id])
        #expect(all.sections[1].bookmarks.map(\.letter) == ["a", "b"])
        #expect(all.bookmarkCount == 3)
        #expect(all.unlistedBookmarkCount == 1)
    }

    @Test func aSearchFindsLabelsTagsMessagesAndSessionTitles() {
        #expect(list("release day").sections.map { $0.bookmarks.map(\.snippet) } == [["Ship the release"]])
        #expect(list("tests pass").sections.map { $0.bookmarks.map(\.letter) } == [["b"]])
        #expect(list("feature").sections.map(\.conversation.id) == [newer.id])
        // A session's title keeps all its bookmarks.
        #expect(list("release work").sections.map { $0.bookmarks.map(\.letter) } == [["a", "b"]])
        #expect(list("nothing like this").sections.isEmpty)
    }

    @Test func aHashSearchFindsTagsByTheirStartOnly() {
        #expect(list("#to").sections.map(\.conversation.id) == [newer.id, older.id])
        #expect(list("#dep").sections.map { $0.bookmarks.map(\.letter) } == [["a"]])
        #expect(list("#release").sections.isEmpty)  // a label, not a tag
    }

    @Test func chosenTagsKeepOnlyBookmarksWithAllOfThemIgnoringCase() {
        #expect(list(tags: ["todo"]).bookmarkCount == 2)
        #expect(list(tags: ["TODO", "deploy"]).sections.map { $0.bookmarks.map(\.label) } == [["Release day"]])
        #expect(list("flag", tags: ["deploy"]).sections.isEmpty)
    }
}
