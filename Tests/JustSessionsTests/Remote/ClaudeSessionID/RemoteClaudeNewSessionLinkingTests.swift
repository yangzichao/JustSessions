import Foundation
import Testing
@testable import JustSessions

/// New Claude Code tabs on an SSH host whose `claude` takes `--session-id`.
@MainActor
struct RemoteClaudeNewSessionLinkingTests {
    private static let host = "devbox"
    private static let projectPath = "/home/me/paper"

    @Test func aNewTabStartsItsCLIWithAnIDOfItsOwnAndATmuxSessionNamedAfterIt() throws {
        let (store, settings) = try makeStore(hostTakesSessionIDs: true)
        defer { tearDown(store, settings) }

        let tab = try openNewClaudeTab(in: store)

        let sessionID = try #require(tab.preassignedSessionID)
        let remoteCommand = try #require(tab.command.arguments.last)
        #expect(remoteCommand.contains("--session-id"))
        #expect(remoteCommand.contains(sessionID))
        #expect(tab.tmuxSessionName == TmuxSessionName.forSession(provider: .claude, sessionID: sessionID))
        #expect(remoteCommand.contains(TmuxSessionName.forSession(provider: .claude, sessionID: sessionID)))
        #expect(tab.sessionIDsKnownAtLaunch.isEmpty)
        #expect(!tab.isWaitingForAppearingSession)
    }

    /// A session started outside the app in the same project is not the tab's, though it appeared first.
    @Test func aNewTabTakesOnlyItsOwnSession() throws {
        let (store, settings) = try makeStore(hostTakesSessionIDs: true)
        defer { tearDown(store, settings) }
        let tab = try openNewClaudeTab(in: store)
        let sessionID = try #require(tab.preassignedSessionID)

        let outside = conversation(sessionID: UUID().uuidString.lowercased())
        listOnHost(store, [outside])
        #expect(tab.conversation == nil)

        let own = conversation(sessionID: sessionID)
        listOnHost(store, [outside, own])
        #expect(tab.conversation?.id == own.id)
        #expect(tab.tmuxSessionName == TmuxSessionName.forConversation(own))
    }

    /// The second tab's CLI may write its session first.
    @Test func twoNewTabsInAProjectEachTakeTheirOwnSession() throws {
        let (store, settings) = try makeStore(hostTakesSessionIDs: true)
        defer { tearDown(store, settings) }
        let first = try openNewClaudeTab(in: store)
        let second = try openNewClaudeTab(in: store)

        let secondSession = conversation(sessionID: try #require(second.preassignedSessionID))
        listOnHost(store, [secondSession])
        #expect(first.conversation == nil)
        #expect(second.conversation?.id == secondSession.id)

        let firstSession = conversation(sessionID: try #require(first.preassignedSessionID))
        listOnHost(store, [secondSession, firstSession])
        #expect(first.conversation?.id == firstSession.id)
        #expect(second.conversation?.id == secondSession.id)
    }

    /// A tab waiting for any new session, as one started before the host's answer came, never takes a session that
    /// another tab started with.
    @Test func aTabWaitingForAnyNewSessionLeavesOtherTabsSessionsAlone() throws {
        let support = RemoteClaudeSessionIDFlagSupport(runner: RemoteCommandRecorder().runner(
            answering: (0, RemoteClaudeSessionIDFlagSupportTests.helpWithFlag)
        ))
        let (store, settings) = try makeStore(support: support)
        defer { tearDown(store, settings) }
        let waitingForAny = try openNewClaudeTab(in: store)
        #expect(support.check(host: Self.host, startCommand: nil) == true)
        let startedWithID = try openNewClaudeTab(in: store)

        let startedWithIDSession = conversation(sessionID: try #require(startedWithID.preassignedSessionID))
        listOnHost(store, [startedWithIDSession])

        #expect(startedWithID.conversation?.id == startedWithIDSession.id)
        #expect(waitingForAny.conversation == nil)
    }

    @Test func aHostWithoutAnAnswerStartsTheCLIWithoutAnID() throws {
        let (store, settings) = try makeStore(hostTakesSessionIDs: false)
        defer { tearDown(store, settings) }

        let tab = try openNewClaudeTab(in: store)

        #expect(tab.preassignedSessionID == nil)
        #expect(tab.command.arguments.last?.contains("--session-id") == false)
        #expect(tab.tmuxSessionName?.hasPrefix(TmuxSessionName.forSession(provider: .claude, sessionID: "new-")) == true)
        #expect(tab.isWaitingForAppearingSession)
    }

    @Test func onlyHostsWithClaudeAreAsked() async throws {
        let recorder = RemoteCommandRecorder()
        let support = RemoteClaudeSessionIDFlagSupport(runner: recorder.runner(answering: (0, "")))
        let (store, settings) = try makeStore(support: support)
        defer { tearDown(store, settings) }

        store.setInstalledProviders([.codex], on: .ssh(Self.host))
        store.checkClaudeSessionIDFlagIfUnanswered(on: Self.host)
        store.checkClaudeSessionIDFlagIfUnanswered(on: "laptop")
        try await Task.sleep(for: .milliseconds(300))
        #expect(recorder.commands.isEmpty)

        store.setInstalledProviders([.codex, .claude], on: .ssh(Self.host))
        store.checkClaudeSessionIDFlagIfUnanswered(on: Self.host)
        try await expectEventually(timeout: .seconds(10)) { recorder.commands.count == 1 }
        #expect(recorder.commands.first?.host == Self.host)
    }

    // MARK: Helpers

    private func makeStore(hostTakesSessionIDs: Bool) throws -> (ConversationStore, IsolatedUserDefaults) {
        let support = RemoteClaudeSessionIDFlagSupport(runner: RemoteCommandRecorder().runner(
            answering: (0, RemoteClaudeSessionIDFlagSupportTests.helpWithFlag)
        ))
        if hostTakesSessionIDs { #expect(support.check(host: Self.host, startCommand: nil) == true) }
        return try makeStore(support: support)
    }

    private func makeStore(support: RemoteClaudeSessionIDFlagSupport) throws -> (ConversationStore, IsolatedUserDefaults) {
        let settings = try IsolatedUserDefaults()
        let store = ConversationStore(
            adapters: [],
            userDefaults: settings.userDefaults,
            sessionNotifier: RecordingSessionNotifier(),
            remoteClaudeSessionIDFlagSupport: support,
            startsBackgroundPolling: false
        )
        store.remoteHostList.add(Self.host)
        return (store, settings)
    }

    private func tearDown(_ store: ConversationStore, _ settings: IsolatedUserDefaults) {
        store.closeAllTerminals()
        settings.removeSuite()
    }

    private func openNewClaudeTab(in store: ConversationStore) throws -> TerminalSession {
        store.launchNewRemoteSession(provider: .claude, host: Self.host, projectPath: Self.projectPath)
        return try #require(store.terminalSessions.last)
    }

    /// What a refresh of the host does once its copy is in.
    private func listOnHost(_ store: ConversationStore, _ conversations: [Conversation]) {
        store.applyRemoteHostConversations(conversations, host: Self.host)
    }

    private func conversation(sessionID: String) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: Self.projectPath,
            suggestedTitle: sessionID,
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl"),
            host: .ssh(Self.host)
        )
    }
}
