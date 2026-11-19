import Foundation
import Testing

@testable import JustSessions

struct NonInteractiveSSHOptionsTests {
    static let expectedOptions = [
        "-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3",
        "-o", "RemoteCommand=none", "-o", "ClearAllForwardings=yes",
    ]
    static let sharingOptions = SSHConnectionSharing.options(controlPath: "/tmp/justsessions-ssh-501/refresh-id/master")

    @Test func remoteCommandsUseTheSharedOptionsWithoutATerminal() {
        #expect(RemoteHostCommandRunner.nonInteractiveSSHOptions == Self.expectedOptions)
        #expect(
            RemoteHostCommandRunner.sshArguments(host: "devbox", command: "true", connectionSharingOptions: Self.sharingOptions)
                == ["-T"] + Self.expectedOptions + Self.sharingOptions + ["devbox", "true"])
    }

    @Test func rsyncConnectsWithTheSharedOptionsWithoutATerminal() throws {
        let remoteShell = RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: Self.sharingOptions)
        let arguments = RemoteSessionMirror.rsyncArguments(
            for: .claude, source: "devbox:.claude/", destination: "/cache/claude/", remoteShell: remoteShell
        )
        let remoteShellIndex = try #require(arguments.firstIndex(of: "-e")) + 1

        #expect(
            arguments[remoteShellIndex] == "ssh -T -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=10"
                + " -o ServerAliveCountMax=3 -o RemoteCommand=none -o ClearAllForwardings=yes"
                + " -o ControlMaster=auto -o ControlPath=/tmp/justsessions-ssh-501/refresh-id/master -o ControlPersist=60")
    }

    @Test func theShellStartupCheckKeepsItsTerminal() {
        #expect(
            RemoteShellStartupCheck.sshArguments(host: "devbox", command: "true", connectionSharingOptions: Self.sharingOptions)
                == ["-tt"] + Self.expectedOptions + Self.sharingOptions + ["devbox", "true"])
    }

    @Test func tabsDoNotShareAConnection() {
        let tab = RemoteCLICommandBuilder(inheritedEnvironment: [:], loginConnections: SSHLoginConnections(close: { _, _ in }))
            .sshCommand(host: "devbox", remoteCommand: "true")

        #expect(!tab.arguments.contains { $0.hasPrefix("Control") })
    }

    @Test func aTabGoesThroughTheHostsLogin() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let connections = SSHLoginConnections(close: { _, _ in })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)
        connections.add(directory, for: "devbox")

        let tab = RemoteCLICommandBuilder(inheritedEnvironment: [:], loginConnections: connections)
            .sshCommand(host: "devbox", remoteCommand: "true")

        #expect(Array(tab.arguments.prefix(5)) == ["-t", "-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)"])
        #expect(Array(tab.arguments.suffix(2)) == ["devbox", "true"])
    }

    @Test func aReconnectingTabGoesThroughTheLoginOpenNow() throws {
        let earlier = try makeTemporaryDirectory()
        let current = try makeTemporaryDirectory()
        defer {
            try? FileManager.default.removeItem(at: earlier)
            try? FileManager.default.removeItem(at: current)
        }
        let connections = SSHLoginConnections(close: { _, _ in })
        FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: earlier), contents: nil)
        connections.add(earlier, for: "devbox")
        let builder = RemoteCLICommandBuilder(inheritedEnvironment: [:], loginConnections: connections)
        let tab = builder.sshCommand(host: "devbox", remoteCommand: "true")

        connections.disconnect("devbox")
        let withoutLogin = builder.withCurrentLogin(tab, host: "devbox")
        FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: current), contents: nil)
        connections.add(current, for: "devbox")
        let throughNewLogin = builder.withCurrentLogin(withoutLogin, host: "devbox")

        #expect(
            withoutLogin.arguments
                == RemoteCLICommandBuilder(
                    inheritedEnvironment: [:],
                    loginConnections: SSHLoginConnections(close: { _, _ in })
                ).sshCommand(host: "devbox", remoteCommand: "true").arguments)
        #expect(throughNewLogin.arguments == builder.sshCommand(host: "devbox", remoteCommand: "true").arguments)
        #expect(throughNewLogin.arguments.contains("ControlPath=\(SSHLoginConnections.controlPath(in: current))"))
    }
}
