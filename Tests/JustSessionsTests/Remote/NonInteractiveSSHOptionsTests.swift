import Testing
@testable import JustSessions

/// Commands and copies over SSH without a terminal notice a host that stops answering, as after the Mac sleeps.
struct NonInteractiveSSHOptionsTests {
    static let expectedOptions = [
        "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3",
    ]

    @Test func remoteCommandsUseTheSharedOptions() {
        #expect(RemoteHostCommandRunner.nonInteractiveSSHOptions == Self.expectedOptions)
        #expect(RemoteHostCommandRunner.sshArguments(host: "devbox", command: "true") == Self.expectedOptions + ["devbox", "true"])
    }

    @Test func rsyncConnectsWithTheSharedOptions() throws {
        let arguments = RemoteSessionMirror.rsyncArguments(for: .claude, source: "devbox:.claude/", destination: "/cache/claude/")
        let remoteShellIndex = try #require(arguments.firstIndex(of: "-e")) + 1

        #expect(arguments[remoteShellIndex]
            == "ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10 -o ServerAliveCountMax=3")
        #expect(arguments[remoteShellIndex] == (["ssh"] + RemoteHostCommandRunner.nonInteractiveSSHOptions).joined(separator: " "))
    }
}
