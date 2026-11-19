import Darwin
import Foundation
import Testing

@testable import JustSessions

/// Close and end session, from a tab's menu, closes the tab and ends the tmux session its CLI runs in without asking,
/// for a session's tab and for a new session's tab not yet linked to its session. Runs the installed tmux in a sandbox
/// server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxCloseAndEndSessionTests {
    @Test func aSessionsTabClosesAndItsCLIInTmuxEnds() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\nexec /bin/sleep 600\n")
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString.lowercased(),
            projectPath: sandbox.project.path,
            suggestedTitle: "Paper",
            updatedAt: .now,
            sourceFile: sandbox.root.appendingPathComponent("session.jsonl")
        )
        let store = ConversationStore(
            adapters: [StaticConversationAdapter(discoveredConversations: [conversation])],
            commandResolver: sandbox.resolver,
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })

        store.launch(conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        tab.startIfNeeded()
        try #require(
            await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] }, "\(sandbox.launchDiagnostics(for: tab))")
        try #require(await sandbox.waitForPaneProcess(in: store, for: tab))
        let cliProcessID = try #require(tab.tmuxPaneProcessID)
        try #require(cliProcessID > 0)
        #expect(tab.closingNeed.hasRunningCLI)

        store.closeTerminalEndingSession(tab.id)

        #expect(store.terminalSessions.isEmpty)
        #expect(!store.isRunningInTmux(conversation))
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
        #expect(await sandbox.waitUntil { kill(cliProcessID, 0) != 0 })
    }

    @Test func aNewSessionsTabNotYetLinkedClosesAndItsTmuxSessionEnds() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "codex", script: "#!/bin/sh\nexec /bin/sleep 600\n")
        let store = ConversationStore(adapters: [], commandResolver: sandbox.resolver, startsBackgroundPolling: false)
        defer { store.closeAllTerminals() }
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })

        try store.launchNewSession(provider: .codex, in: ProjectLocation(host: .thisMac, path: sandbox.project.path))
        let tab = try #require(store.terminalSessions.last)
        let tmuxSessionName = try #require(tab.tmuxSessionName)
        tab.startIfNeeded()
        try #require(
            await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] }, "\(sandbox.launchDiagnostics(for: tab))")
        #expect(tab.conversation == nil)

        store.closeTerminalEndingSession(tab.id)

        #expect(store.terminalSessions.isEmpty)
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
    }
}
