import Foundation
import Testing

@testable import JustSessions

/// The tmux messages here are what tmux 1.8 to 3.6a printed when tried against each other's servers.
struct RemoteHostTmuxFindingTests {
    @Test func findsTheLineSayingTheServerCantBeReached() {
        let output = "justsessions-claude-new-1a2b3c4d\n  Protocol version mismatch (client 8, server 7)\nmore"
        #expect(RemoteHostTmuxFinding.unreachableServerMessage(in: output) == "Protocol version mismatch (client 8, server 7)")
        #expect(RemoteHostTmuxFinding.unreachableServerMessage(in: "no server running on /tmp/tmux-1000/default") == nil)
        #expect(RemoteHostTmuxFinding.unreachableServerMessage(in: "") == nil)
    }

    @Test func noTmuxIsANote() {
        let finding = RemoteHostTmuxFinding.finding(in: hostCheckOutput(["tmux-path": ""]), context: hostCheckContext())
        #expect(finding.status == .note)
    }

    @Test func aSupportedTmuxWithNoServerRunningPasses() {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: "tmux 3.4", server: "no server running on /tmp/tmux-1000/default", serverExit: 1),
            context: hostCheckContext()
        )
        #expect(finding.status == .passed)
        #expect(finding.hostOutput == "tmux 3.4")
        #expect(finding.commandToRunYourself == "ssh devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"tmux -V; tmux ls\"'")
    }

    @Test func aServerOfTheClientsVersionPasses() {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: "tmux 3.4", server: "3.4", serverExit: 0),
            context: hostCheckContext()
        )
        #expect(finding.status == .passed)
    }

    @Test(arguments: [
        "protocol version mismatch (client 8, server 7)",
        "server exited unexpectedly",
        "server version is too old for client",
    ])
    func aServerTheClientCannotReachIsAProblem(message: String) {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: "tmux 3.6a", server: message, serverExit: 1),
            context: hostCheckContext()
        )
        #expect(finding.status == .problem)
        #expect(finding.hostOutput == message)
        #expect(finding.summary.contains("tmux 3.6a"))
    }

    @Test func aServerOfAnotherVersionIsAWarning() {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: "tmux 3.6a", server: "3.4", serverExit: 0),
            context: hostCheckContext()
        )
        #expect(finding.status == .warning)
        #expect(finding.summary.contains("3.4"))
    }

    @Test(arguments: ["tmux 1.8", "tmux 2.1", "tmux 2.5"])
    func aTmuxOlderThanTwoPointSixIsAWarning(version: String) {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: version, server: "no server running on /tmp/tmux-1000/default", serverExit: 1),
            context: hostCheckContext()
        )
        #expect(finding.status == .warning)
    }

    @Test func anotherErrorIsAWarningWithWhatTmuxPrinted() {
        let finding = RemoteHostTmuxFinding.finding(
            in: tmuxOutput(client: "tmux 3.4", server: "open terminal failed: not a terminal", serverExit: 1),
            context: hostCheckContext()
        )
        #expect(finding.status == .warning)
        #expect(finding.hostOutput == "open terminal failed: not a terminal")
    }

    @Test func readsVersions() {
        #expect(RemoteHostTmuxFinding.version(inVersionOutput: "tmux 3.6a") == "3.6a")
        #expect(RemoteHostTmuxFinding.version(inVersionOutput: "tmux next-3.7") == "next-3.7")
        #expect(RemoteHostTmuxFinding.version(inVersionOutput: "bash: tmux: command not found") == nil)
        #expect(RemoteHostTmuxFinding.isOlderThanSupported("2.5"))
        #expect(RemoteHostTmuxFinding.isOlderThanSupported("1.10"))
        #expect(!RemoteHostTmuxFinding.isOlderThanSupported("2.6"))
        #expect(!RemoteHostTmuxFinding.isOlderThanSupported("next-3.7"))
        #expect(!RemoteHostTmuxFinding.isOlderThanSupported("master"))
    }

    private func tmuxOutput(client: String, server: String, serverExit: Int32) -> RemoteHostCheckOutput {
        hostCheckOutput([
            "tmux-path": "/usr/bin/tmux",
            "tmux-version": client,
            "tmux-server": server,
            "tmux-server-exit": "\(serverExit)",
        ])
    }
}
