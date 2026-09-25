import Darwin
import Foundation
import Testing
@testable import JustSessions

/// Runs the installed tmux in a sandbox server; see `ThisMacTmuxSandbox`.
@MainActor
struct ThisMacTmuxKeepAliveTests {
    @Test func theCLIOutlivesItsTabsClientAndReattachingStartsNoSecondOne() async throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        let log = sandbox.root.appendingPathComponent("cli.log")
        let cli = try sandbox.writeExecutable(named: "claude", script: """
            #!/bin/sh
            {
              echo "pid=$$"
              echo "directory=$(pwd -P)"
              for argument in "$@"; do echo "argument=$argument"; done
              echo "COLORTERM=$COLORTERM"
            } >> "$CLI_LOG"
            exec sleep 60
            """)
        let name = "justsessions-claude-keepalive"
        let command = sandbox.server.command(
            attachingTo: name,
            running: sandbox.cliCommand(cli, arguments: ["--resume", "abc", "say;"], extraEnvironment: ["CLI_LOG": log.path])
        )

        let firstClient = try sandbox.startClient(command)
        #expect(await sandbox.waitUntil { loggedProcessIDs(in: log).count == 1 })
        let cliProcessID = try #require(loggedProcessIDs(in: log).first)
        #expect(sandbox.server.sessionNames() == [name])
        #expect(sandbox.server.paneProcessIDsBySessionName() == [name: cliProcessID])
        let logLines = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
        let loggedDirectory = try #require(logLines.first { $0.hasPrefix("directory=") }?.dropFirst("directory=".count))
        #expect(URL(fileURLWithPath: String(loggedDirectory)).resolvingSymlinksInPath().path == sandbox.project.resolvingSymlinksInPath().path)
        #expect(logLines.filter { $0.hasPrefix("argument=") } == ["argument=--resume", "argument=abc", "argument=say;"])
        #expect(logLines.contains("COLORTERM=truecolor"))
        // A pane target needs the colon to name the session exactly.
        let options = sandbox.tmuxOutput([
            "display-message", "-p", "-t", "=\(name):",
            "#{session_name} #{status} #{mouse} #{prefix} #{focus-events} #{escape-time} #{extended-keys} #{extended-keys-format}",
        ])
        // tmux prints on and off options as 1 and 0.
        #expect(options == "\(name) off 1 None 1 10 always csi-u\n")

        // Closing a tab ends its tmux client with SIGTERM.
        let clientProcessIDs = sandbox.tmuxOutput(["list-clients", "-F", "#{client_pid}"]).split(separator: "\n").compactMap { Int32($0) }
        #expect(clientProcessIDs.count == 1)
        for clientProcessID in clientProcessIDs { kill(clientProcessID, SIGTERM) }
        #expect(await sandbox.waitUntil { !firstClient.isRunning })
        #expect(sandbox.server.sessionNames() == [name])
        #expect(kill(cliProcessID, 0) == 0)

        let secondClient = try sandbox.startClient(command)
        defer { secondClient.terminate() }
        #expect(await sandbox.waitUntil { sandbox.tmuxOutput(["list-clients", "-F", "#{session_name}"]) == "\(name)\n" })
        #expect(loggedProcessIDs(in: log) == [cliProcessID])
        #expect(sandbox.server.paneProcessIDsBySessionName() == [name: cliProcessID])

        let sessionName = "justsessions-claude-abc"
        sandbox.server.renameSession(from: name, to: sessionName)
        #expect(sandbox.server.sessionNames() == [sessionName])

        sandbox.server.killSession(named: sessionName)
        #expect(await sandbox.waitUntil { kill(cliProcessID, 0) != 0 })
        #expect(await sandbox.waitUntil { !secondClient.isRunning })
        #expect(sandbox.server.sessionNames().isEmpty)
    }

    /// tmux takes a plain target as a prefix too, which would end or rename another session.
    @Test func aSessionIsNamedExactlyNotByPrefix() throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }
        _ = sandbox.tmuxOutput(["-f", "/dev/null", "new-session", "-d", "-s", "justsessions-codex-abcdef", "--", "/bin/sleep", "60"])

        sandbox.server.renameSession(from: "justsessions-codex-abc", to: "justsessions-codex-renamed")
        sandbox.server.killSession(named: "justsessions-codex-abc")
        #expect(sandbox.server.sessionNames() == ["justsessions-codex-abcdef"])

        sandbox.server.killSession(named: "justsessions-codex-abcdef")
        #expect(sandbox.server.sessionNames().isEmpty)
    }

    @Test func theVersionCheckAcceptsTheInstalledTmux() throws {
        guard let sandbox = try ThisMacTmuxSandbox.make() else { return }
        defer { sandbox.tearDown() }

        #expect(!sandbox.server.isKnownToHaveSupportedVersion)
        #expect(sandbox.server.hasSupportedVersion())
        #expect(sandbox.server.isKnownToHaveSupportedVersion)
        #expect(sandbox.resolver.thisMacTmuxServer()?.executablePath == sandbox.server.executablePath)
    }

    private func loggedProcessIDs(in log: URL) -> [Int32] {
        let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").compactMap { line in
            line.hasPrefix("pid=") ? Int32(line.dropFirst("pid=".count)) : nil
        }
    }
}
