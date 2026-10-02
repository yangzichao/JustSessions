import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct DetachedCLIActivityTmuxTests {
    @Test func aCLILeftRunningInTmuxShowsWhatItDoesUntilItEnds() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\nexec /bin/sleep 60\n")
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
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        store.launch(conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        tab.startIfNeeded()
        try #require(await sandbox.waitUntil { sandbox.server.sessionNames() == [TmuxSessionName.forConversation(conversation)] }, "\(sandbox.launchDiagnostics(for: tab))")
        // A session can be listed before its pane process is ready. Wait for the production lookup to
        // record the PID; stop here on failure rather than passing PID 0 to the registry or kill().
        try #require(await sandbox.waitForPaneProcess(in: store, for: tab))
        let cliProcessID = try #require(tab.tmuxPaneProcessID)
        try #require(cliProcessID > 0)
        // Claude Code's live registry entry for the CLI in tmux.
        let claudeRegistry = ClaudeLiveSessionRegistry(configurationDirectory: sandbox.root.appendingPathComponent("claude"))
        try FileManager.default.createDirectory(at: claudeRegistry.sessionsDirectory, withIntermediateDirectories: true)
        try #"{"sessionId":"\#(conversation.sessionID)","status":"busy"}"#
            .write(to: claudeRegistry.sessionsDirectory.appendingPathComponent("\(cliProcessID).json"), atomically: true, encoding: .utf8)

        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(tab.cliActivity == .working)

        store.closeTerminal(tab.id, endingTmuxSession: false)
        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(store.detachedCLIActivities == [conversation.id: .working])

        // The CLI ends on its own, and tmux ends its session with it.
        kill(cliProcessID, SIGTERM)
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty && kill(cliProcessID, 0) != 0 })
        #expect(store.isRunningInTmux(conversation))
        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry)
        #expect(!store.isRunningInTmux(conversation))
        #expect(store.detachedCLIActivities.isEmpty)
    }
}
