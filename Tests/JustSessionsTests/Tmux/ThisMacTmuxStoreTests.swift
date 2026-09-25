import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxStoreTests {
    @Test func aResumedSessionKeepsRunningInTmuxAfterItsTabClosesUntilEnded() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "claude", script: "#!/bin/sh\nexec sleep 60\n")
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
            commandResolver: sandbox.resolver
        )
        defer { store.closeAllTerminals() }
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)

        // Tabs run the CLI directly until a refresh has checked the tmux version.
        #expect(store.commandResolver.thisMacTmuxServer() == nil)
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        #expect(store.tmuxSessionNamesByHost[.thisMac] == [])

        store.launch(conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        #expect(tab.tmuxSessionName == tmuxSessionName)
        #expect(tab.command.executablePath == sandbox.server.executablePath)
        tab.startIfNeeded()
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] })
        await store.lookUpTmuxPaneProcesses()
        let cliProcessID = tab.cliProcessID
        #expect(cliProcessID == sandbox.server.paneProcessIDsBySessionName()[tmuxSessionName])
        #expect(cliProcessID != tab.processID)

        store.closeTerminal(tab.id, endingTmuxSession: false)
        #expect(store.isRunningInTmux(conversation))
        #expect(store.hasTerminal(for: conversation))
        #expect(await sandbox.waitUntil { sandbox.tmuxOutput(["list-clients"]).isEmpty })
        #expect(sandbox.server.sessionNames() == [tmuxSessionName])
        #expect(kill(cliProcessID, 0) == 0)

        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        #expect(store.isRunningInTmux(conversation))

        store.endTmuxSession(for: conversation)
        #expect(!store.isRunningInTmux(conversation))
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
        #expect(await sandbox.waitUntil { kill(cliProcessID, 0) != 0 })
    }

    @Test func aNewSessionRunsInATmuxSessionOfItsOwnThatClosingCanEnd() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "codex", script: "#!/bin/sh\nexec sleep 60\n")
        let store = ConversationStore(adapters: [], commandResolver: sandbox.resolver)
        defer { store.closeAllTerminals() }
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })

        try store.launchNewSession(provider: .codex, in: ProjectLocation(host: .thisMac, path: sandbox.project.path))
        let tab = try #require(store.terminalSessions.last)
        let tmuxSessionName = try #require(tab.tmuxSessionName)
        #expect(tmuxSessionName.hasPrefix("justsessions-codex-new-"))
        #expect(tab.terminalView.sendsShiftReturnAsCSIu)
        tab.startIfNeeded()
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] })

        store.closeTerminal(tab.id, endingTmuxSession: true)
        #expect(store.terminalSessions.isEmpty)
        #expect(await sandbox.waitUntil { sandbox.server.sessionNames().isEmpty })
    }

    @Test func aTabWhoseCLIExitedLeavesNothingRunning() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        try sandbox.writeExecutable(named: "codex", script: "#!/bin/sh\nexit 0\n")
        let store = ConversationStore(adapters: [], commandResolver: sandbox.resolver)
        defer { store.closeAllTerminals() }
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })

        try store.launchNewSession(provider: .codex, in: ProjectLocation(host: .thisMac, path: sandbox.project.path))
        let tab = try #require(store.terminalSessions.last)
        tab.startIfNeeded()
        #expect(await sandbox.waitUntil { tab.hasExited })

        #expect(!tab.canKeepCLIRunningAfterClose)
        #expect(sandbox.server.sessionNames().isEmpty)
    }
}
