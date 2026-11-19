import AppKit
import Testing

@testable import JustSessions

/// Keys with Control reach a CLI in this Mac's tmux as the keys they are, with either engine. A CLI that asks for
/// modifyOtherKeys 2, as Codex does, gets `CSI u`, with Ctrl-/ as itself rather than the Ctrl-_ that its legacy byte
/// 0x1f names; any other CLI gets the legacy byte where there is one. Before, Ghostty sent 0x1f for Ctrl-/, and SwiftTerm
/// sent nothing for Ctrl-/, Ctrl-7, Ctrl-2, Ctrl-Return, or Ctrl-Backspace. Ctrl-[ is left out: tmux would join its lone
/// Esc with the next key. Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxControlKeyTests {
    @Test(arguments: TerminalEngine.allCases, [true, false])
    func controlKeysReachTheCLIAsTheKeysTheyAre(_ engine: TerminalEngine, cliAsksForModifyOtherKeys: Bool) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let presses = ControlKeyPress.all.filter { $0.bytesForLegacyCLI != "\u{1b}" }
        let expectedBytes =
            presses
            .map { cliAsksForModifyOtherKeys ? $0.bytesForCLIAskingForModifyOtherKeys : $0.bytesForLegacyCLI }
            .joined()
        let keyLog = sandbox.root.appendingPathComponent("keys")
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let cli = try sandbox.writeExecutable(named: "codex", script: TmuxKeyboardReaderFixture.script)
        var environment = ["KEY_LOG": keyLog.path, "READY_MARKER": readyMarker.path, "KEY_BYTE_COUNT": "\(expectedBytes.utf8.count)"]
        if cliAsksForModifyOtherKeys { environment["ASKS_FOR_EXTENDED_KEYS"] = "1" }
        let tmuxSessionName = "justsessions-codex-control-keys"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .codex,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New codex session",
            command: sandbox.server.command(attachingTo: tmuxSessionName, running: sandbox.cliCommand(cli, extraEnvironment: environment)),
            tmuxSessionName: tmuxSessionName
        )
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = tab.terminalView
        window.makeFirstResponder(tab.terminalView)
        defer {
            tab.close()
            window.close()
        }

        tab.startIfNeeded()
        try #require(
            await sandbox.waitUntil {
                FileManager.default.fileExists(atPath: readyMarker.path)
                    && sandbox.tmuxOutput(["list-clients", "-F", "#{session_name}"]) == "\(tmuxSessionName)\n"
                    && screenText(of: tab.terminalView).contains("KEY_READER_READY")
            }, "\(sandbox.launchDiagnostics(for: tab))")
        for press in presses {
            press.press(in: tab.terminalView, windowNumber: window.windowNumber)
        }

        _ = await sandbox.waitUntil { ((try? Data(contentsOf: keyLog))?.count ?? 0) >= expectedBytes.utf8.count }
        let receivedBytes = String(decoding: (try? Data(contentsOf: keyLog)) ?? Data(), as: UTF8.self)
        #expect(
            receivedBytes == expectedBytes,
            "Received:\(ControlKeyPress.readable(receivedBytes))\nExpected:\(ControlKeyPress.readable(expectedBytes))"
        )
    }
}
