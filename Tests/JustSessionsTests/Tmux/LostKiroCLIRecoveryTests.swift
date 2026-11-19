import Darwin
import Foundation
import Testing

@testable import JustSessions

/// A Kiro CLI a tab left running in tmux under its temporary name, as every Kiro tab closed before Kiro CLI 2.16's
/// sessions were listed did, is found by Kiro's lock on its session; see `ConversationStore+LostKiroCLIs`. Runs the
/// installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct LostKiroCLIRecoveryTests {
    @Test func theCLIsTmuxSessionTakesTheSessionsNameAndCloseAndDeleteEndsItThenDeletes() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let sessionsDirectory = sandbox.root.appendingPathComponent("kiro home/sessions/cli")
        // Known before the tab starts, so the tab never links to it, as the app couldn't before DSC-08's fix.
        let sessionID = UUID().uuidString.lowercased()
        try KiroSessionFolderFixture(sessionsDirectory: sessionsDirectory).writeSession(
            id: sessionID, projectPath: sandbox.project.path, title: "hi", messageLines: [KiroSessionFolderFixture.prompt("hi")]
        )
        let sessionFile = sessionsDirectory.appendingPathComponent("\(sessionID).jsonl")
        let lockFile = KiroSessionLock.file(forSessionFile: sessionFile)
        let lock = ShellQuoting.quoted(lockFile.path)
        // Kiro's chat process, below the tab's `kiro-cli`: holds the lock while it runs and removes it once the CLI ends,
        // within 0.2 seconds of `kill-session` for Kiro CLI 2.34.0's V2 and V3. It watches its parent rather than
        // trapping the hangup, which a process the test runner starts may ignore.
        let chat = try sandbox.writeExecutable(
            named: "kiro-cli-chat",
            script: """
                #!/bin/sh
                printf '{"pid":%s,"started_at":"%s"}' "$$" "$(/bin/date -u +%Y-%m-%dT%H:%M:%S.000Z)" > \(lock)
                while /bin/kill -0 "$PPID" 2>/dev/null; do /bin/sleep 0.1; done
                /bin/rm -f \(lock)
                """)
        _ = try sandbox.writeExecutable(named: "kiro-cli", script: "#!/bin/sh\n\(ShellQuoting.quoted(chat.path))\n")
        let adapter = KiroAdapter(
            sessionsDirectory: sessionsDirectory,
            deletionExecutableURL: try sandbox.writeExecutable(named: "kiro-delete", script: KiroHomeFixture.successfulDeletionScript)
        )
        let store = ConversationStore(adapters: [adapter], commandResolver: sandbox.resolver, startsBackgroundPolling: false)
        defer { store.closeAllTerminals() }
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        try store.launchNewSession(provider: .kiro, in: ProjectLocation(host: .thisMac, path: sandbox.project.path))
        let tab = try #require(store.terminalSessions.last)
        tab.startIfNeeded()
        let temporaryName = try #require(tab.tmuxSessionName)
        #expect(temporaryName.hasPrefix(LostKiroCLIs.temporaryNamePrefix))
        try #require(
            await sandbox.waitUntil { KiroSessionLock.heldLock(forSessionFile: sessionFile) != nil },
            "\(sandbox.launchDiagnostics(for: tab))")
        let chatProcessID = try #require(KiroSessionLock(file: lockFile)?.processID)
        defer { kill(chatProcessID, SIGKILL) }
        // While the tab shows it, its CLI isn't anyone's to take.
        store.refreshThisMac()
        #expect(await sandbox.waitUntil { !store.isScanningThisMac })
        #expect(sandbox.server.sessionNames() == [temporaryName])

        store.closeTerminal(tab.id, endingTmuxSession: false)
        store.refreshThisMac()

        let sessionName = TmuxSessionName.forSession(provider: .kiro, sessionID: sessionID)
        try #require(await sandbox.waitUntil { sandbox.server.sessionNames() == [sessionName] }, "\(sandbox.server.sessionNames())")
        let conversation = try #require(store.conversations.first { $0.sessionID == sessionID })
        #expect(await sandbox.waitUntil { store.isRunningInTmux(conversation) })

        store.closeAndDelete(conversation)

        #expect(await sandbox.waitUntil { !store.conversations.contains { $0.id == conversation.id } && !store.isDeletingSessions })
        #expect(store.alert == nil)
        #expect(sandbox.server.sessionNames().isEmpty)
        #expect(kill(chatProcessID, 0) != 0)
        #expect(!FileManager.default.fileExists(atPath: lockFile.path))
        #expect(!FileManager.default.fileExists(atPath: sessionFile.path))
    }
}
