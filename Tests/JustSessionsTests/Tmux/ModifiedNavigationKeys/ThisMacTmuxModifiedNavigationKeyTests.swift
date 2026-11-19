import AppKit
import Testing

@testable import JustSessions

/// Arrows, Home, and End with Shift, Option, or Control reach a CLI in this Mac's tmux as xterm sends them, with either
/// engine. The stand-in asks for keyboard modes as Codex does. tmux ignores the kitty protocol, so the tab's terminal
/// stays in its legacy keyboard mode, where SwiftTerm sent nothing for Shift-Left, Codex's key for a waiting question.
/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxModifiedNavigationKeyTests {
    @Test(arguments: TerminalEngine.allCases)
    func modifiedNavigationKeysReachTheCLIAsXtermSendsThem(_ engine: TerminalEngine) async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let presses = ModifiedNavigationKeyPress.all
        let expectedBytes = presses.map(\.bytesTheCLIReceives).joined()
        let keyLog = sandbox.root.appendingPathComponent("keys")
        let readyMarker = sandbox.root.appendingPathComponent("ready")
        let cli = try sandbox.writeExecutable(named: "codex", script: TmuxKeyboardReaderFixture.script)
        let tmuxSessionName = "justsessions-codex-keys"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .codex,
            projectPath: sandbox.project.path,
            action: .new,
            displayTitle: "New codex session",
            command: sandbox.server.command(
                attachingTo: tmuxSessionName,
                running: sandbox.cliCommand(
                    cli,
                    extraEnvironment: [
                        "KEY_LOG": keyLog.path,
                        "READY_MARKER": readyMarker.path,
                        "KEY_BYTE_COUNT": "\(expectedBytes.utf8.count)",
                        "ASKS_FOR_EXTENDED_KEYS": "1",
                    ])
            ),
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
        try #require(
            await sandbox.waitUntil {
                FileManager.default.fileExists(atPath: readyMarker.path)
                    && sandbox.tmuxOutput(["list-clients", "-F", "#{session_name}"]) == "\(tmuxSessionName)\n"
                    && screenText(of: tab.terminalView).contains("KEY_READER_READY")
            }, "\(sandbox.launchDiagnostics(for: tab))")
        for press in presses {
            tab.terminalView.keyDown(with: press.event(windowNumber: window.windowNumber))
        }

        _ = await sandbox.waitUntil { ((try? Data(contentsOf: keyLog))?.count ?? 0) >= expectedBytes.utf8.count }
        let receivedBytes = String(decoding: (try? Data(contentsOf: keyLog)) ?? Data(), as: UTF8.self)
        #expect(
            receivedBytes == expectedBytes,
            "Received: \(Self.readable(receivedBytes))\nExpected: \(Self.readable(expectedBytes))"
        )
    }

    private static func readable(_ bytes: String) -> String {
        bytes.replacingOccurrences(of: "\u{1b}", with: " ESC")
    }
}
