import Foundation
import Testing

@testable import JustSessions

/// SSH tabs send each keystroke as it is typed, not in OpenSSH's 20 ms batches, where this Mac's `ssh` takes the
/// option; an older `ssh` would refuse to connect with it.
struct SSHKeystrokeTimingTests {
    @Test func theCheckTellsAnOptionSSHKnowsFromOneItRefuses() {
        #expect(SSHKeystrokeTiming.sshAccepts(["-o", "ServerAliveInterval=15"]))
        #expect(!SSHKeystrokeTiming.sshAccepts(["-o", "JustSessionsMadeUpOption=no"]))
    }

    @Test func anSSHThatCantRunPassesNoOption() {
        #expect(!SSHKeystrokeTiming.sshAccepts(SSHKeystrokeTiming.unobscuredOptions, sshExecutable: "/nonexistent/ssh"))
    }

    /// `withCurrentLogin` finds a login's options right after `-t`, so the option comes after them.
    @Test func aTabPassesTheOptionAfterItsLogin() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let connections = SSHLoginConnections(close: { _, _ in })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)
        connections.add(directory, for: "devbox")
        let builder = RemoteCLICommandBuilder(
            inheritedEnvironment: [:],
            loginConnections: connections,
            keystrokeTimingOptions: SSHKeystrokeTiming.unobscuredOptions
        )

        let tab = builder.sshCommand(host: "devbox", remoteCommand: "true")

        #expect(Array(tab.arguments.prefix(5)) == ["-t", "-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)"])
        #expect(tab.arguments.contains("ObscureKeystrokeTiming=no"))
        #expect(builder.withCurrentLogin(tab, host: "devbox").arguments == tab.arguments)
    }

    @Test func aTabOnAnOlderSSHPassesNone() {
        let tab = RemoteCLICommandBuilder(
            inheritedEnvironment: [:],
            loginConnections: SSHLoginConnections(close: { _, _ in }),
            keystrokeTimingOptions: []
        ).sshCommand(host: "devbox", remoteCommand: "true")

        #expect(!tab.arguments.contains { $0.hasPrefix("ObscureKeystrokeTiming") })
    }

    /// A tab that goes through a Connect… login has its keystrokes sent by the login's master, whose setting decides.
    @Test func theConnectLoginPassesTheOption() {
        let arguments = SSHLogin.sshArguments(
            host: "devbox",
            controlPath: "/tmp/justsessions-ssh-501/login-id/master",
            keystrokeTimingOptions: SSHKeystrokeTiming.unobscuredOptions
        )

        #expect(arguments.contains("ObscureKeystrokeTiming=no"))
        #expect(Array(arguments.suffix(2)) == ["devbox", "true"])
    }
}
