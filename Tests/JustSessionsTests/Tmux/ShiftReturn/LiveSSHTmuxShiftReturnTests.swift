import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import JustSessions

@MainActor
struct LiveSSHTmuxShiftReturnTests {
    @Test(
        .enabled(if: LiveSSHTmuxHost.host != nil, "Set JUSTSESSIONS_LIVE_SSH_HOST to an SSH host with tmux"),
        arguments: TerminalEngine.allCases)
    func shiftReturnReachesACLIInTheHostsTmuxDistinctFromReturn(_ engine: TerminalEngine) async throws {
        try await expectKeysToReachTheReader(engine: engine, name: "shift-return", expectedBytes: "\u{1b}[13;2u\r") { tab, windowNumber in
            tab.terminalView.keyDown(with: Self.returnKeyEvent(modifiers: .shift, windowNumber: windowNumber))
            tab.terminalView.keyDown(with: Self.returnKeyEvent(modifiers: [], windowNumber: windowNumber))
        }
    }

    /// Ctrl-[ is left out, as in `ThisMacTmuxControlKeyTests`: tmux would join its lone Esc with the next key. The keys
    /// the tab sends as their legacy bytes, such as Ctrl-_, Ctrl-], and Ctrl-A, reach the CLI as CSI u from tmux 3.5 on,
    /// which encodes them again for a CLI that asks for modifyOtherKeys 2; tmux 3.4 passes them on as sent.
    @Test(
        .enabled(if: LiveSSHTmuxHost.host != nil, "Set JUSTSESSIONS_LIVE_SSH_HOST to an SSH host with tmux"),
        arguments: TerminalEngine.allCases)
    func controlKeysReachACLIInTheHostsTmuxAsTheKeysTheyAre(_ engine: TerminalEngine) async throws {
        let host = try #require(LiveSSHTmuxHost.host)
        let tmuxVersion = try LiveSSHTmuxHost.ssh(host, "tmux -V").trimmingCharacters(in: .whitespacesAndNewlines)
        let tmuxEncodesLegacyBytesAgain = Self.tmuxVersionIsAtLeastThreePointFive(tmuxVersion)
        let presses = ControlKeyPress.all.filter { $0.bytesForLegacyCLI != "\u{1b}" }
        let expectedBytes = presses.map { press in
            tmuxEncodesLegacyBytesAgain ? press.bytesForCLIAskingForModifyOtherKeys : Self.bytesTheTabSends(for: press)
        }.joined()
        try await expectKeysToReachTheReader(engine: engine, name: "control-keys", expectedBytes: expectedBytes) { tab, windowNumber in
            for press in presses { press.press(in: tab.terminalView, windowNumber: windowNumber) }
        }
    }

    private func expectKeysToReachTheReader(
        engine: TerminalEngine, name: String, expectedBytes: String, press: (TerminalSession, Int) -> Void
    ) async throws {
        let host = try #require(LiveSSHTmuxHost.host)
        let folder = "/tmp/justsessions-live-keys-\(UUID().uuidString)"
        let tmuxSessionName = "justsessions-codex-live-\(name)-\(engine.rawValue)"
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
        window.makeFirstResponder(tab.terminalView)
        defer {
            tab.close()
            window.close()
        }

        tab.startIfNeeded()
        try #require(
            await LiveSSHTmuxHost.waitUntil { screenText(of: tab.terminalView).contains("KEY_READER_READY") },
            "\(screenText(of: tab.terminalView))")
        press(tab, window.windowNumber)

        var receivedBytes = ""
        _ = await LiveSSHTmuxHost.waitUntil {
            receivedBytes = (try? LiveSSHTmuxHost.ssh(host, "cat \(folder)/keys")) ?? ""
            return receivedBytes.utf8.count >= expectedBytes.utf8.count
        }
        let tmuxVersion = (try? LiveSSHTmuxHost.ssh(host, "tmux -V")) ?? "unknown"
        #expect(
            receivedBytes == expectedBytes,
            "\(tmuxVersion) on \(host)\nReceived:\(ControlKeyPress.readable(receivedBytes))\nExpected:\(ControlKeyPress.readable(expectedBytes))"
        )
    }

    private static func bytesTheTabSends(for press: ControlKeyPress) -> String {
        TerminalControlKey(press.event(windowNumber: 0))?.bytesForTmux ?? press.bytesForLegacyCLI
    }

    /// `tmux -V` prints `tmux 3.4`, `tmux 3.5a`, or `tmux next-3.6`.
    private static func tmuxVersionIsAtLeastThreePointFive(_ version: String) -> Bool {
        let digits = version.drop { !$0.isNumber }.prefix { $0.isNumber || $0 == "." }
        let parts = digits.split(separator: ".").compactMap { Int($0) }
        guard parts.count >= 2 else { return false }
        return parts[0] > 3 || (parts[0] == 3 && parts[1] >= 5)
    }

    private static func returnKeyEvent(modifiers: NSEvent.ModifierFlags, windowNumber: Int) -> NSEvent {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: UInt16(kVK_Return)
        )!
    }
}
