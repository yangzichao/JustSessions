import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct CloseAndDeleteThisMacTmuxTests {
    /// The CLI writes to its session file a second after its terminal hangs up, as a CLI saving on exit might.
    /// Deleted before then, the file would come back.
    @Test func theSessionIsDeletedOnlyOnceItsCLIHasExited() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let sessionFile = sandbox.root.appendingPathComponent("session.jsonl")
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let exitMarker = sandbox.root.appendingPathComponent("exited")
        try "{}\n".write(to: sessionFile, atomically: true, encoding: .utf8)
        try sandbox.writeExecutable(
            named: "claude",
            script: "#!/bin/sh\ntrap '/bin/sleep 1; echo late >> \"\(sessionFile.path)\"; /usr/bin/touch \"\(exitMarker.path)\"; exit 0' HUP\n/usr/bin/touch \"\(readyMarker.path)\"\nwhile :; do /bin/sleep 0.2; done\n"
        )
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString.lowercased(),
            projectPath: sandbox.project.path,
            suggestedTitle: "Paper",
            updatedAt: .now,
            sourceFile: sessionFile
        )
        let store = ConversationStore(
            adapters: [FileBackedConversationAdapter(provider: .claude, conversations: [conversation])],
            commandResolver: sandbox.resolver,
            startsBackgroundPolling: false
        )
        defer { store.closeAllTerminals() }
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        store.launch(conversation, action: .resume)
        let tab = try #require(store.terminalSessions.last)
        tab.startIfNeeded()
        let tmuxSessionName = TmuxSessionName.forConversation(conversation)
        try #require(await sandbox.waitUntil { sandbox.server.sessionNames() == [tmuxSessionName] }, "\(sandbox.launchDiagnostics(for: tab))")
        try #require(await sandbox.waitForPaneProcess(in: store, for: tab))
        let cliProcessID = try #require(tab.tmuxPaneProcessID)
        try #require(await sandbox.waitUntil { FileManager.default.fileExists(atPath: readyMarker.path) })

        store.closeAndDelete(conversation)

        #expect(store.terminalSessions.isEmpty)
        #expect(await sandbox.waitUntil { !store.conversations.contains { $0.id == conversation.id } && !store.isDeletingSessions })
        #expect(kill(cliProcessID, 0) != 0)
        #expect(FileManager.default.fileExists(atPath: exitMarker.path))
        #expect(sandbox.server.sessionNames().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(store.alert == nil)
    }
}
