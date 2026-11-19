import AppKit
import Testing

@testable import JustSessions

@MainActor
struct ThisMacTmuxTerminalTitleTests {
    @Test(arguments: TerminalEngine.allCases)
    func theTitleACLISetsInTmuxReachesItsTab(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let threadTitle = "01a10846-4c77-75e2-bec8-ab638..."
        let cli = try sandbox.writeExecutable(
            named: "codex",
            script: """
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
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
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
