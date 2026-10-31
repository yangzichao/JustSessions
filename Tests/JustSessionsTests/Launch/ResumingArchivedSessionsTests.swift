import Foundation
import Testing
@testable import JustSessions

/// Resuming an archived session brings it back from the archive; showing a running session's tab does not.
@MainActor
struct ResumingArchivedSessionsTests {
    @Test func resumingAnArchivedSessionUnarchivesIt() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.setArchived(true, conversations: [conversation])

        store.resume(conversation)

        #expect(store.runningTerminal(for: conversation) != nil)
        #expect(!store.archivedSessions.isArchived(conversationID: conversation.id))
        #expect(ArchivedSessions.load(from: sandbox.userDefaults).archivedConversationIDs.isEmpty)
    }

    @Test func resumingSeveralSessionsUnarchivesEachOne() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let first = sandbox.conversation()
        let second = sandbox.conversation()
        let store = sandbox.makeStore(listing: [first, second])
        store.setArchived(true, conversations: [first, second])

        store.resume([first, second])

        #expect(store.archivedSessions.archivedConversationIDs.isEmpty)
        #expect(store.terminalSessions.count == 2)
    }

    @Test func resumingASessionWhoseTabRunsShowsTheTabAndUnarchivesIt() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.launch(conversation, action: .resume)
        let tab = try #require(store.runningTerminal(for: conversation))
        store.setArchived(true, conversations: [conversation])
        store.selectTerminal(nil)

        store.resume(conversation)

        #expect(store.selectedTerminalID == tab.id)
        #expect(store.terminalSessions.count == 1)
        #expect(!store.archivedSessions.isArchived(conversationID: conversation.id))
    }

    @Test func showingARunningSessionsTabLeavesItArchived() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation()
        let store = sandbox.makeStore(listing: [conversation])
        store.launch(conversation, action: .resume)
        store.setArchived(true, conversations: [conversation])
        store.selectTerminal(nil)

        #expect(store.showRunningCLI(for: conversation))
        #expect(store.archivedSessions.isArchived(conversationID: conversation.id))
    }

    @Test func aSessionWhoseFolderIsGoneStaysArchived() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let conversation = Conversation.fixture(projectPath: sandbox.root.appendingPathComponent("removed").path)
        let store = sandbox.makeStore(listing: [conversation])
        store.setArchived(true, conversations: [conversation])

        store.resume([conversation])

        #expect(store.terminalSessions.isEmpty)
        #expect(store.archivedSessions.isArchived(conversationID: conversation.id))
    }

    @Test func droppingAnArchivedRowOnTheTerminalsUnarchivesIt() throws {
        let sandbox = try TerminalEngineLaunchSandbox(engine: .swiftTerm)
        defer { sandbox.tearDown() }
        let resumedWhole = sandbox.conversation()
        let shownInSplit = sandbox.conversation()
        let store = sandbox.makeStore(listing: [resumedWhole, shownInSplit])
        store.setArchived(true, conversations: [resumedWhole, shownInSplit])

        // With no tab selected, it fills the terminals and resumes.
        store.showDroppedRow(.session(resumedWhole), at: .wholeArea)
        #expect(store.runningTerminal(for: resumedWhole) != nil)
        #expect(!store.archivedSessions.isArchived(conversationID: resumedWhole.id))

        // Beside the selected tab, also when its own tab is already open.
        store.launch(shownInSplit, action: .resume)
        let resumedWholeTab = try #require(store.runningTerminal(for: resumedWhole))
        store.selectTerminal(resumedWholeTab.id)
        store.showDroppedRow(.session(shownInSplit), at: .split(.right, .sideBySide))
        #expect(store.shownSplit != nil)
        #expect(!store.archivedSessions.isArchived(conversationID: shownInSplit.id))
    }
}
