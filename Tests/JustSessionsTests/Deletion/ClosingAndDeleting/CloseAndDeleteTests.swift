import Foundation
import Testing
@testable import JustSessions

/// Close and delete: a session a tab shows, or whose CLI runs in tmux, has its CLI ended, then is deleted.
@MainActor
struct CloseAndDeleteTests {
    @Test func aSessionWhoseTabIsInAnotherWindowHasItClosedThenIsDeleted() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation
        _ = try #require(sandbox.openTab(of: conversation, in: sandbox.second))
        #expect(sandbox.first.cliEndingBeforeDeletion(of: conversation) == .closingTab)

        sandbox.first.closeAndDelete(conversation)

        #expect(sandbox.second.terminalSessions.isEmpty)
        try await expectEventually { !sandbox.first.conversations.contains { $0.id == conversation.id } }
        #expect(sandbox.first.alert == nil)
    }

    @Test func aSessionWhoseTabIsInThisWindowHasItClosedThenIsDeleted() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation
        _ = try #require(sandbox.openTab(of: conversation, in: sandbox.first))
        #expect(sandbox.first.cliEndingBeforeDeletion(of: conversation) == .closingTab)

        sandbox.first.closeAndDelete(conversation)

        #expect(sandbox.first.terminalSessions.isEmpty)
        try await expectEventually { !sandbox.first.conversations.contains { $0.id == conversation.id } }
        #expect(sandbox.first.alert == nil)
    }

    @Test func aSessionStillRunningInTmuxWithoutATabHasItsCLIEndedThenIsDeleted() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation
        sandbox.first.tmuxSessionNamesByHost[.thisMac] = [TmuxSessionName.forConversation(conversation)]
        #expect(sandbox.first.cliEndingBeforeDeletion(of: conversation) == .endingCLIInTmux)

        sandbox.first.closeAndDelete(conversation)

        #expect(!sandbox.first.isRunningInTmux(conversation))
        try await expectEventually { !sandbox.first.conversations.contains { $0.id == conversation.id } }
        #expect(sandbox.first.alert == nil)
    }

    @Test func aSessionNothingRunsNeedsNoClosing() throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }

        #expect(sandbox.first.cliEndingBeforeDeletion(of: sandbox.conversation) == nil)
    }

    /// The refresh read tmux before the CLI ended. Had the deletion waited for it as usual, it would have skipped the
    /// session, which that refresh still listed as running.
    @Test func aRefreshThatListedTheCLIBeforeItEndedDoesNotKeepTheSession() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let conversation = sandbox.conversation
        let tmuxName = TmuxSessionName.forConversation(conversation)
        let store = sandbox.first
        store.tmuxSessionNamesByHost[.thisMac] = [tmuxName]
        store.hostRefreshStatuses[.thisMac] = .refreshing

        store.closeAndDelete(conversation)
        try await Task.sleep(for: .milliseconds(300))
        #expect(store.conversations.contains { $0.id == conversation.id })
        store.tmuxSessionNamesByHost[.thisMac] = [tmuxName]
        store.hostRefreshStatuses[.thisMac] = .refreshed(.now)

        try await expectEventually { !store.conversations.contains { $0.id == conversation.id } }
        #expect(store.alert == nil)
    }

    @Test func anSSHSessionEndsItsCLIOnTheHostBeforeItIsDeleted() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let conversation = try sandbox.savedConversation(onHost: "devbox")
        let recorder = RemoteCommandRecorder()
        let runner = recorder.runner(answering: (0, ""))
        let store = sandbox.makeStore(listing: [conversation], remoteDeletion: RemoteConversationDeletion(runner: runner))
        let tmuxName = TmuxSessionName.forConversation(conversation)
        store.tmuxSessionNamesByHost[.ssh("devbox")] = [tmuxName]
        #expect(store.cliEndingBeforeDeletion(of: conversation) == .endingCLIInTmux)

        store.closeAndDelete(conversation, remoteRunner: runner)
        try await expectEventually { !store.conversations.contains { $0.id == conversation.id } }

        #expect(store.alert == nil)
        let commands = recorder.commands.map(\.command)
        #expect(commands.count == 2)
        #expect(commands.first == RemoteTmuxCommands.killSessionWaitingForCLIExitCommand(
            tmuxName, on: "devbox", timeoutSeconds: ConversationStore.cliExitTimeoutBeforeDeletion
        ))
        #expect(commands.last?.contains(conversation.sessionID) == true)
    }
}
