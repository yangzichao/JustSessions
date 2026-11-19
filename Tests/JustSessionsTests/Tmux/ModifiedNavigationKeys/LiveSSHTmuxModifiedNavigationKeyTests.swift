import AppKit
import Foundation
import Testing

@testable import JustSessions

/// `ThisMacTmuxModifiedNavigationKeyTests` on a real SSH host: a tab opened with the app's own `ssh` command runs the
/// key reader in the host's tmux, with the session options every tab sets there, and the reader records what reaches
/// it. Option-Left and Option-Right alone are left out: they stay Esc b and Esc f, which the host's own
/// `extended-keys` setting decides how to pass on. Opt-in, since it needs a host:
///
///     JUSTSESSIONS_LIVE_SSH_HOST=justsessions-test swift test --filter LiveSSHTmuxModifiedNavigationKeyTests
///
/// The reader's folder on the host and its tmux session are removed afterwards.
@MainActor
struct LiveSSHTmuxModifiedNavigationKeyTests {
    @Test(
        .enabled(if: LiveSSHTmuxHost.host != nil, "Set JUSTSESSIONS_LIVE_SSH_HOST to an SSH host with tmux"),
        arguments: TerminalEngine.allCases)
    func modifiedNavigationKeysReachACLIInTheHostsTmux(_ engine: TerminalEngine) async throws {
        let host = try #require(LiveSSHTmuxHost.host)
        let presses = ModifiedNavigationKeyPress.all.filter { !($0.modifiers == .option && ($0.key == .left || $0.key == .right)) }
        let expectedBytes = presses.map(\.bytesTheCLIReceives).joined()
        let folder = "/tmp/justsessions-live-keys-\(UUID().uuidString)"
        let tmuxSessionName = "justsessions-codex-live-keys-\(engine.rawValue)"
        try LiveSSHTmuxHost.ssh(host, "mkdir -p \(folder) && cat > \(folder)/reader.py", input: TmuxKeyboardReaderFixture.script)
        defer { _ = try? LiveSSHTmuxHost.ssh(host, "tmux kill-session -t =\(tmuxSessionName) 2>/dev/null; rm -rf \(folder)") }

        let startCommand =
            "KEY_LOG=\(folder)/keys READY_MARKER=\(folder)/ready KEY_BYTE_COUNT=\(expectedBytes.utf8.count) "
            + "ASKS_FOR_EXTENDED_KEYS=1 python3 \(folder)/reader.py"
        let tab = TerminalSession(
            engine: engine,
            conversation: nil,
            provider: .codex,
            projectPath: folder,
            action: .new,
            displayTitle: "New codex session",
            command: RemoteCLICommandBuilder().command(
                host: host,
                provider: .codex,
                projectPath: folder,
                arguments: [],
                tmuxSessionName: tmuxSessionName,
                usesHostTmuxPrefix: false,
                startCommand: startCommand
            ),
            host: .ssh(host),
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
            await LiveSSHTmuxHost.waitUntil { screenText(of: tab.terminalView).contains("KEY_READER_READY") },
            "\(screenText(of: tab.terminalView))")
        for press in presses {
            tab.terminalView.keyDown(with: press.event(windowNumber: window.windowNumber))
        }

        var receivedBytes = ""
        _ = await LiveSSHTmuxHost.waitUntil {
            receivedBytes = (try? LiveSSHTmuxHost.ssh(host, "cat \(folder)/keys")) ?? ""
            return receivedBytes.utf8.count >= expectedBytes.utf8.count
        }
        let tmuxVersion = (try? LiveSSHTmuxHost.ssh(host, "tmux -V")) ?? "unknown"
        #expect(
            receivedBytes == expectedBytes,
            "\(tmuxVersion) on \(host)\nReceived: \(LiveSSHTmuxHost.readable(receivedBytes))\nExpected: \(LiveSSHTmuxHost.readable(expectedBytes))"
        )
    }
}
