import Foundation
import Testing

@testable import JustSessions

struct SessionsDeletedWhenTabClosesTests {
    @Test func markingAndUnmarkingChangesOnlyTheSessionsNamed() {
        var sessions = SessionsDeletedWhenTabCloses()
        sessions.setDeletedWhenTabCloses(true, conversationIDs: ["first", "second"])
        sessions.setDeletedWhenTabCloses(false, conversationIDs: ["second", "never-marked"])

        #expect(sessions.conversationIDs == ["first"])
        #expect(sessions.isDeletedWhenTabCloses(conversationID: "first"))
        #expect(!sessions.isDeletedWhenTabCloses(conversationID: "second"))
    }

    @Test func theChoiceOutlivesARestart() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let sessions = SessionsDeletedWhenTabCloses(conversationIDs: ["claude:b", "claude:a"])

        sessions.save(to: isolatedUserDefaults.userDefaults)

        #expect(SessionsDeletedWhenTabCloses.load(from: isolatedUserDefaults.userDefaults) == sessions)
        let savedValue = isolatedUserDefaults.userDefaults.stringArray(forKey: SessionsDeletedWhenTabCloses.userDefaultsKey)
        #expect(savedValue == ["claude:a", "claude:b"])
    }
}
