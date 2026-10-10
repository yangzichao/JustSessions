import Foundation
import Testing
@testable import JustSessions

/// Runs the real `/usr/bin/ssh` with `-G`, which prints the settings it would connect with and exits without
/// connecting, against an `~/.ssh/config` of the kind people write for logging in by hand.
struct SSHConfigOverrideTests {
    static let handLoginConfig = """
        Host devbox
          HostName 192.0.2.10
          RemoteCommand tmux new-session -A -s main
          RequestTTY force
          LocalForward 18080 localhost:8080
          DynamicForward 11080
          ExitOnForwardFailure yes

        """

    @Test func theConfigAloneMakesSSHRefuseACommand() throws {
        let result = try Self.resolvedSettings(sshArguments: ["devbox", "true"])

        #expect(result.exitStatus == 255)
        #expect(result.output.contains("Cannot execute command-line and remote command."))
    }

    @Test func backgroundCommandsRunWithoutTheRemoteCommandForwardsOrTerminal() throws {
        let result = try Self.resolvedSettings(sshArguments: RemoteHostCommandRunner.sshArguments(host: "devbox", command: "true", connectionSharingOptions: []))

        #expect(result.exitStatus == 0)
        #expect(Self.setting("requesttty", in: result.output) == ["false"])
        #expect(Self.setting("remotecommand", in: result.output).isEmpty)
        #expect(Self.setting("localforward", in: result.output).isEmpty)
        #expect(Self.setting("dynamicforward", in: result.output).isEmpty)
    }

    @Test func rsyncConnectsWithoutTheRemoteCommandForwardsOrTerminal() throws {
        let remoteShell = RemoteSessionMirror.rsyncRemoteShell(connectionSharingOptions: [])
            .split(separator: " ").dropFirst().map(String.init)
        let result = try Self.resolvedSettings(sshArguments: remoteShell + ["devbox", "rsync --server"])

        #expect(result.exitStatus == 0)
        #expect(Self.setting("requesttty", in: result.output) == ["false"])
        #expect(Self.setting("remotecommand", in: result.output).isEmpty)
        #expect(Self.setting("localforward", in: result.output).isEmpty)
    }

    @Test func theShellStartupCheckGetsItsTerminalWithoutTheRemoteCommand() throws {
        let result = try Self.resolvedSettings(sshArguments: RemoteShellStartupCheck.sshArguments(host: "devbox", command: "true", connectionSharingOptions: []))

        #expect(result.exitStatus == 0)
        #expect(Self.setting("requesttty", in: result.output) == ["force"])
        #expect(Self.setting("remotecommand", in: result.output).isEmpty)
    }

    @Test func backgroundCommandsShareTheHostsConnection() throws {
        let sharingOptions = SSHConnectionSharing.options(userControlPath: nil, socketDirectory: "/tmp/justsessions-ssh-501")
        let result = try Self.resolvedSettings(sshArguments: RemoteHostCommandRunner.sshArguments(
            host: "devbox", command: "true", connectionSharingOptions: sharingOptions
        ))

        #expect(result.exitStatus == 0)
        #expect(Self.setting("controlmaster", in: result.output) == ["auto"])
        #expect(Self.setting("controlpersist", in: result.output) == ["60"])
        let controlPath = try #require(Self.setting("controlpath", in: result.output).first)
        #expect(controlPath.hasPrefix("/tmp/justsessions-ssh-501/"))
        #expect(controlPath.count == "/tmp/justsessions-ssh-501/".count + 40)
    }

    /// A tab keeps the forwards, which the user may want while a session runs.
    @Test func aTabRunsItsCommandInPlaceOfTheRemoteCommand() throws {
        let tab = RemoteCLICommandBuilder(inheritedEnvironment: [:]).sshCommand(host: "devbox", remoteCommand: "true")
        let result = try Self.resolvedSettings(sshArguments: tab.arguments)

        #expect(result.exitStatus == 0)
        #expect(Self.setting("remotecommand", in: result.output).isEmpty)
        #expect(Self.setting("localforward", in: result.output) == ["18080 [localhost]:8080"])
    }

    private static func resolvedSettings(sshArguments: [String]) throws -> (exitStatus: Int32, output: String) {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let config = root.appendingPathComponent("config")
        try handLoginConfig.write(to: config, atomically: true, encoding: .utf8)
        return try #require(BoundedProcessRunner.result(
            ofExecutable: "/usr/bin/ssh",
            arguments: ["-F", config.path, "-G"] + sshArguments,
            includesStandardError: true,
            timeout: 10
        ))
    }

    /// The values `ssh -G` printed for a setting, which it prints in lowercase, one line per value.
    private static func setting(_ name: String, in output: String) -> [String] {
        output.split(whereSeparator: \.isNewline).compactMap { line in
            line.hasPrefix(name + " ") ? String(line.dropFirst(name.count + 1)) : nil
        }
    }
}
