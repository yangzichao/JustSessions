import AppKit
import Foundation
import Testing
@testable import JustSessions

/// A CLI in tmux asks for the terminal's background to pick light or dark colors. tmux answers from what it learned
/// from the tab's terminal, so after a theme change it has to learn the new background.
@MainActor
@Suite(.serialized)
struct TerminalThemeChangeInTmuxTests {
    @Test func aCLIInTmuxSeesTheNewBackgroundAfterTheThemeChanges() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let appearanceStore = TerminalAppearanceStore(userDefaults: settings.userDefaults)
        let themeStore = AppThemeStore(userDefaults: settings.userDefaults)
        appearanceStore.setMode(.light)
        let replyLog = sandbox.root.appendingPathComponent("background-replies.log")
        let probe = try sandbox.writeExecutable(named: "background-probe", script: Self.backgroundProbeScript)
        let terminalView = SelectableTerminalView(
            frame: NSRect(x: 0, y: 0, width: 600, height: 400), appearanceStore: appearanceStore, themeStore: themeStore
        )
        defer { terminalView.terminate() }
        terminalView.startProcess(
            executable: sandbox.server.executablePath,
            args: ["-L", ThisMacTmuxServer.socketName, "-f", "/dev/null", "new-session", "-A", "-s", "probe",
                   probe.path, replyLog.path],
            environment: sandbox.environment.map { "\($0.key)=\($0.value)" },
            currentDirectory: sandbox.project.path
        )
        let lightBackground = Self.reply(for: AppThemeColors.justSessionsLight.contentSurface)
        let darkBackground = Self.reply(for: AppThemeColors.justSessionsDark.contentSurface)
        // tmux and the probe can take a while to start while the other tests run.
        let sawLightBackground = await Self.waitUntil(timeout: .seconds(30)) { Self.lastReply(in: replyLog) == lightBackground }
        #expect(sawLightBackground, "\(Self.diagnostics(replyLog: replyLog, terminalView: terminalView))")
        guard sawLightBackground else { return }

        appearanceStore.setMode(.dark)

        let sawDarkBackground = await Self.waitUntil(timeout: .seconds(5)) { Self.lastReply(in: replyLog) == darkBackground }
        #expect(sawDarkBackground, "\(Self.diagnostics(replyLog: replyLog, terminalView: terminalView))")
    }

    /// Waits without blocking the main thread, where the terminal reads tmux's output.
    private static func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    private static func diagnostics(replyLog: URL, terminalView: SelectableTerminalView) -> String {
        let replies = (try? String(contentsOf: replyLog, encoding: .utf8))?.split(separator: "\n").suffix(5) ?? []
        let screen = String(decoding: terminalView.getTerminal().getBufferAsData(), as: UTF8.self)
        return "last replies: \(replies); terminal: \(screen.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    /// Asks for the background every 200 ms and writes each reply on a line of its own.
    private static let backgroundProbeScript = #"""
    #!/usr/bin/perl
    use strict;
    use warnings;
    use IO::Select;
    use Time::HiRes qw(time sleep);
    my $log_path = shift;
    system("/bin/stty raw -echo");
    my $input = IO::Select->new(\*STDIN);
    while (1) {
        syswrite(STDOUT, "\e]11;?\e\\");
        my $reply = "";
        my $deadline = time + 1;
        while (time < $deadline && $reply !~ /(\e\\|\a)$/) {
            next unless $input->can_read(0.05);
            my $chunk;
            last unless sysread(STDIN, $chunk, 256);
            $reply .= $chunk;
        }
        $reply =~ s/\e/ESC/g;
        open(my $log, ">>", $log_path) or die;
        print $log "$reply\n";
        close $log;
        sleep 0.2;
    }
    """#

    private static func lastReply(in log: URL) -> String? {
        (try? String(contentsOf: log, encoding: .utf8))?.split(separator: "\n").last.map(String.init)
    }

    /// The `rgb:` reply for a 0xRRGGBB color, as tmux writes it.
    private static func reply(for hexValue: UInt32) -> String {
        let channels = [16, 8, 0].map { String(format: "%02x", (hexValue >> UInt32($0)) & 0xFF) }
        return "ESC]11;rgb:\(channels.map { $0 + $0 }.joined(separator: "/"))ESC\\"
    }
}
