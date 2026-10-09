import Testing
@testable import JustSessions

/// Commands and copies over SSH without a terminal notice a host that stops answering, as after the Mac sleeps, and
/// leave out the `~/.ssh/config` settings meant for logging in by hand.
struct NonInteractiveSSHOptionsTests {
    static let expectedOptions = [
        "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3",
        "-o", "RemoteCommand=none", "-o", "ClearAllForwardings=yes",
    ]

    @Test func remoteCommandsUseTheSharedOptionsWithoutATerminal() {
        #expect(RemoteHostCommandRunner.nonInteractiveSSHOptions == Self.expectedOptions)
        #expect(RemoteHostCommandRunner.sshArguments(host: "devbox", command: "true") == ["-T"] + Self.expectedOptions + ["devbox", "true"])
    }

    @Test func rsyncConnectsWithTheSharedOptionsWithoutATerminal() throws {
        let arguments = RemoteSessionMirror.rsyncArguments(for: .claude, source: "devbox:.claude/", destination: "/cache/claude/")
        let remoteShellIndex = try #require(arguments.firstIndex(of: "-e")) + 1

        #expect(arguments[remoteShellIndex] == "ssh -T -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10"
            + " -o ServerAliveCountMax=3 -o RemoteCommand=none -o ClearAllForwardings=yes")
        #expect(arguments[remoteShellIndex] == (["ssh", "-T"] + RemoteHostCommandRunner.nonInteractiveSSHOptions).joined(separator: " "))
    }

    /// It runs the host's shell in a terminal, as a tab does.
    @Test func theShellStartupCheckKeepsItsTerminal() {
        #expect(RemoteShellStartupCheck.sshArguments(host: "devbox", command: "true") == ["-tt"] + Self.expectedOptions + ["devbox", "true"])
    }
}
