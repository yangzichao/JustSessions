import Foundation
import Testing
@testable import JustSessions

/// Every command the app runs in an SSH host's login shell starts it as the host needs, with `JUSTSESSIONS=1`.
struct RemoteShellStartupTests {
    @Test func eachStartupStartsTheLoginShellWithTheAppsVariable() {
        #expect(RemoteShellStartup.interactive.command(running: "tmux -V")
            == #"exec /usr/bin/env JUSTSESSIONS=1 "$SHELL" -lic 'tmux -V'"#)
        #expect(RemoteShellStartup.loginOnly.command(running: "tmux -V")
            == #"exec /usr/bin/env JUSTSESSIONS=1 "$SHELL" -lc 'tmux -V'"#)
    }

    @Test func aLoginOnlyHostsTabStartsEveryShellWithoutTheInteractiveStartup() throws {
        let host = "login-only-\(UUID().uuidString.prefix(8))"
        RemoteHostShellStartups.shared.setStartup(.loginOnly, on: host)
        defer { RemoteHostShellStartups.shared.setStartup(.interactive, on: host) }

        let tab = RemoteCLICommandBuilder().command(
            host: host,
            provider: .claude,
            projectPath: "/srv/app",
            arguments: ["--resume", "abc"],
            tmuxSessionName: "justsessions-claude-abc",
            usesHostTmuxPrefix: false
        )
        let remoteCommand = try #require(tab.arguments.last)
        // The outer shell, which runs the CLI itself without tmux, and the one tmux runs.
        #expect(remoteCommand.components(separatedBy: #""$SHELL" -lc"#).count - 1 == 2)
        #expect(!remoteCommand.contains("-lic"))
        #expect(RemoteHostStatusProbe.command(on: host).hasPrefix(#"exec /usr/bin/env JUSTSESSIONS=1 "$SHELL" -lc "#))
        #expect(RemoteTmuxCommands.killSessionCommand("justsessions-claude-abc", on: host).contains(#""$SHELL" -lc "#))
        // Other hosts keep the interactive startup.
        #expect(RemoteHostStatusProbe.command(on: "devbox").hasPrefix(#"exec /usr/bin/env JUSTSESSIONS=1 "$SHELL" -lic "#))
    }

    @Test func onlyOneCheckOfAHostRunsAtATime() {
        let host = "checking-\(UUID().uuidString.prefix(8))"
        let startups = RemoteHostShellStartups()
        #expect(startups.beginCheck(on: host))
        #expect(!startups.beginCheck(on: host))
        startups.endCheck(on: host)
        #expect(startups.beginCheck(on: host))
    }
}
