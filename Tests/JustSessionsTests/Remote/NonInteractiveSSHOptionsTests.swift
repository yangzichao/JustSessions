import Testing
@testable import JustSessions

/// Commands and copies over SSH without a terminal notice a host that stops answering, as after the Mac sleeps, and
/// leave out the `~/.ssh/config` settings meant for logging in by hand.
struct NonInteractiveSSHOptionsTests {
    static let expectedOptions = [
        "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3",
        "-o", "RemoteCommand=none", "-o", "ClearAllForwardings=yes",
    ]
    static let sharingOptions = SSHConnectionSharing.options(userControlPath: nil, socketDirectory: "/tmp/justsessions-ssh-501")

    @Test func remoteCommandsUseTheSharedOptionsWithoutATerminal() {
        #expect(RemoteHostCommandRunner.nonInteractiveSSHOptions == Self.expectedOptions)
        #expect(RemoteHostCommandRunner.sshArguments(host: "devbox", command: "true", connectionSharingOptions: Self.sharingOptions)
            == ["-T"] + Self.expectedOptions + Self.sharingOptions + ["devbox", "true"])
    }

    @Test func rsyncConnectsWithTheSharedOptionsWithoutATerminal() throws {
        let remoteShell = RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: Self.sharingOptions)
        let arguments = RemoteSessionMirror.rsyncArguments(
            for: .claude, source: "devbox:.claude/", destination: "/cache/claude/", remoteShell: remoteShell
        )
        let remoteShellIndex = try #require(arguments.firstIndex(of: "-e")) + 1

        #expect(arguments[remoteShellIndex] == "ssh -T -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10"
            + " -o ServerAliveCountMax=3 -o RemoteCommand=none -o ClearAllForwardings=yes"
            + " -o ControlMaster=auto -o ControlPath=/tmp/justsessions-ssh-501/%C -o ControlPersist=60")
    }

    /// It runs the host's shell in a terminal, as a tab does.
    @Test func theShellStartupCheckKeepsItsTerminal() {
        #expect(RemoteShellStartupCheck.sshArguments(host: "devbox", command: "true", connectionSharingOptions: Self.sharingOptions)
            == ["-tt"] + Self.expectedOptions + Self.sharingOptions + ["devbox", "true"])
    }

    /// Each tab keeps a connection of its own, so ending one never ends the others' CLIs.
    @Test func tabsDoNotShareAConnection() {
        let tab = RemoteCLICommandBuilder(inheritedEnvironment: [:]).sshCommand(host: "devbox", remoteCommand: "true")

        #expect(!tab.arguments.contains { $0.hasPrefix("Control") })
    }
}
