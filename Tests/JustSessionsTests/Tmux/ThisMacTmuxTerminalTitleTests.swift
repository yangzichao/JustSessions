import AppKit
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxTerminalTitleTests {
    /// A Codex tab reads its thread from this title; see `CodexThreadTitle`.
    @Test(arguments: TerminalEngine.allCases)
    func theTitleACLISetsInTmuxReachesItsTab(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let threadTitle = "01a10846-4c77-75e2-bec8-ab638..."
        // The CLI must outlive the wait: once it exits, tmux replaces the title with the dead pane's status. The wait
        // took 28 s on a CI runner busy with other main-actor tests, so the CLI sleeps until teardown kills the server.
        let cli = try sandbox.writeExecutable(named: "codex", script: """
            #!/bin/sh
            printf '\\033]0;%s\\007' '\(threadTitle)'
            echo TITLE_SET
            sleep 600
            """)
        let tmuxSessionName = "justsessions-codex-title"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .codex,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New Codex session",
            command: sandbox.server.command(attachingTo: tmuxSessionName, running: sandbox.cliCommand(cli)),
            tmuxSessionName: tmuxSessionName
        )
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
        defer {
            tab.close()
            window.close()
        }

        tab.startIfNeeded()

        #expect(await sandbox.waitUntil { tab.terminalTitle == threadTitle }, "\(sandbox.launchDiagnostics(for: tab))")
        #expect(sandbox.tmuxOutput(["display-message", "-p", "-t", "=\(tmuxSessionName):", "#{pane_title}"]) == threadTitle + "\n")
    }
}
