import Foundation
import Testing

@testable import JustSessions

struct ListedProjectSessionRowsTests {
    @Test func listsTheFirstSessionsAndCountsTheRest() {
        let conversations = sessions(count: 35)

        let listed = ListedProjectSessionRows(
            conversations: conversations, pendingNewSessions: [], pinnedItems: PinnedItems(), sessionLimit: 10
        )

        #expect(listed.conversationIDs == conversations.prefix(10).map(\.id))
        #expect(listed.hiddenSessionCount == 25)
    }

    @Test func withoutALimitListsEverySession() {
        let conversations = sessions(count: 35)

        let listed = ListedProjectSessionRows(
            conversations: conversations, pendingNewSessions: [], pinnedItems: PinnedItems(), sessionLimit: nil
        )

        #expect(listed.conversationIDs.count == 35)
        #expect(listed.hiddenSessionCount == 0)
    }

    @Test func oneSessionPastTheLimitIsListedRatherThanHiddenBehindItsOwnRow() {
        let listed = ListedProjectSessionRows(
            conversations: sessions(count: 11), pendingNewSessions: [], pinnedItems: PinnedItems(), sessionLimit: 10
        )

        #expect(listed.conversationIDs.count == 11)
        #expect(listed.hiddenSessionCount == 0)
    }

    @Test func pinnedAndNewSessionsAreListedOnTopOfTheLimit() {
        let unpinned = sessions(count: 15)
        let pinned = Conversation.fixture(sessionID: "pinned", updatedAt: Date(timeIntervalSince1970: 0))
        let newSession = PendingNewSession(
            terminalID: UUID(), provider: .claude, projectDirectoryKey: pinned.projectDirectoryKey,
            title: "New Claude Code session", startedAt: .now
        )
        let pinnedItems = PinnedItems(pinnedConversationIDs: [pinned.id])

        let listed = ListedProjectSessionRows(
            conversations: [pinned] + unpinned, pendingNewSessions: [newSession], pinnedItems: pinnedItems, sessionLimit: 3
        )

        #expect(
            listed.rows.map(\.id) == [
                "conversation:\(pinned.id)",
                "pending:\(newSession.id.uuidString)",
            ] + unpinned.prefix(3).map { "conversation:\($0.id)" })
        #expect(listed.hiddenSessionCount == 12)
    }

    @Test func aHiddenSessionsPlaceCountsOnlyTheSessionsThatAreNotPinned() {
        let unpinned = sessions(count: 15)
        let pinned = Conversation.fixture(sessionID: "pinned")
        let pinnedItems = PinnedItems(pinnedConversationIDs: [pinned.id])
        let conversations = [pinned] + unpinned

        #expect(
            ListedProjectSessionRows.hiddenPlace(
                of: unpinned[12].id, in: conversations, pinnedItems: pinnedItems, sessionLimit: 10
            ) == 12)
        #expect(
            ListedProjectSessionRows.hiddenPlace(
                of: unpinned[9].id, in: conversations, pinnedItems: pinnedItems, sessionLimit: 10
            ) == nil, "Listed")
        #expect(
            ListedProjectSessionRows.hiddenPlace(
                of: pinned.id, in: conversations, pinnedItems: pinnedItems, sessionLimit: 10
            ) == nil, "Pinned sessions are always listed")
        #expect(
            ListedProjectSessionRows.hiddenPlace(
                of: unpinned[12].id, in: conversations, pinnedItems: pinnedItems, sessionLimit: nil
            ) == nil, "Nothing hides without a limit")
        #expect(
            ListedProjectSessionRows.hiddenPlace(
                of: "elsewhere", in: conversations, pinnedItems: pinnedItems, sessionLimit: 10
            ) == nil)
    }

    private func sessions(count: Int) -> [Conversation] {
        (0..<count).map { index in
            Conversation.fixture(sessionID: "session-\(index)", updatedAt: Date(timeIntervalSince1970: TimeInterval(1_000 - index)))
        }
    }
}
