import AppKit
import Carbon.HIToolbox
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`. Either engine sends the same bytes.
@MainActor
struct ThisMacTmuxShiftReturnTests {
    @Test(arguments: TerminalEngine.allCases)
    func shiftReturnReachesTheCLIInTmuxDistinctFromReturn(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let keyLog = sandbox.root.appendingPathComponent("keys")
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let cli = try sandbox.writeExecutable(named: "claude", script: TmuxKeyboardReaderFixture.script)
        let tmuxSessionName = "justsessions-claude-keys"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .claude,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New claude session",
            command: sandbox.server.command(
                attachingTo: tmuxSessionName,
                running: sandbox.cliCommand(cli, extraEnvironment: ["KEY_LOG": keyLog.path, "READY_MARKER": readyMarker.path])
            ),
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
        // A file can appear before tmux's initial screen reaches the terminal. Wait for rendered output too,
        // so key events are sent through an attached, initialized terminal rather than during its handshake.
        try #require(await sandbox.waitUntil {
            FileManager.default.fileExists(atPath: readyMarker.path)
                && sandbox.tmuxOutput(["list-clients", "-F", "#{session_name}"]) == "\(tmuxSessionName)\n"
                && screenText(of: tab.terminalView).contains("KEY_READER_READY")
        }, "\(sandbox.launchDiagnostics(for: tab))")
        // Reproduce a late initialization reply deterministically, rather than relying on CI timing.
        _ = sandbox.tmuxOutput(["send-keys", "-t", "=\(tmuxSessionName):", "-l", "\u{1b}[?65;4;6;18;22c"])
        tab.terminalView.keyDown(with: returnKeyEvent(modifiers: .shift, windowNumber: window.windowNumber))
        tab.terminalView.keyDown(with: returnKeyEvent(modifiers: [], windowNumber: window.windowNumber))

        try #require(await sandbox.waitUntil { (try? Data(contentsOf: keyLog))?.count == 8 })
        let recordedKeys = String(decoding: try Data(contentsOf: keyLog), as: UTF8.self)
        #expect(recordedKeys == "\u{1b}[13;2u\r", "Received bytes: \(Array(recordedKeys.utf8))")
    }

    @Test(arguments: TerminalEngine.allCases)
    func onlyATabWhoseCLIRunsInTmuxOnThisMacSendsShiftReturnAsCSIu(_ engine: TerminalEngine) {
        let command = NativeCLICommand(executablePath: "/bin/sh", arguments: [], workingDirectory: "/tmp", environment: [])
        func tab(host: SessionHost, tmuxSessionName: String?) -> TerminalSession {
            TerminalSession(
                engine: engine,
                conversation: nil,
                provider: .claude,
                projectPath: "/tmp",
                action: .new,
                displayTitle: "New claude session",
                command: command,
                host: host,
                tmuxSessionName: tmuxSessionName
            )
        }

        #expect(tab(host: .thisMac, tmuxSessionName: "justsessions-claude-abc").terminalView.sendsShiftReturnAsCSIu)
        #expect(!tab(host: .thisMac, tmuxSessionName: nil).terminalView.sendsShiftReturnAsCSIu)
        // tmux on an SSH host keeps its own key settings, which may not pass CSI u on.
        #expect(!tab(host: .ssh("devbox"), tmuxSessionName: "justsessions-claude-abc").terminalView.sendsShiftReturnAsCSIu)
    }

    private func returnKeyEvent(modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: UInt16(kVK_Return)
        )!
    }
}
