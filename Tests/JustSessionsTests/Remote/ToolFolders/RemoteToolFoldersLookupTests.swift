import Foundation
import Testing
@testable import JustSessions

/// Runs the lookup's script in a local shell whose environment stands in for the host's login shell.
struct RemoteToolFoldersLookupTests {
    typealias HostShell = RemotePiFixture.HostShell

    @Test(arguments: HostShell.installed)
    func followsTheVariablesTheHostsShellSets(shell: HostShell) throws {
        let home = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("pi-agent"), withIntermediateDirectories: true)
        try #"{"sessionDir": "~/pi-sessions"}"#.write(to: home.appendingPathComponent("pi-agent/settings.json"), atomically: true, encoding: .utf8)

        let folders = try Self.folders(shell: shell, home: home.path, variables: [
            "CLAUDE_CONFIG_DIR": "/data/claude",
            "CODEX_HOME": "~/codex home",
            "KIRO_HOME": "relative/kiro",
            "PI_CODING_AGENT_DIR": "~/pi-agent",
        ])

        #expect(folders == RemoteToolFolders(
            claude: "/data/claude",
            codex: home.path + "/codex home",
            antigravity: home.path + "/.gemini/antigravity-cli",
            kiro: home.path + "/.kiro/sessions/cli",
            pi: home.path + "/pi-sessions"
        ))
    }

    @Test(arguments: HostShell.installed)
    func aHostThatSetsNothingKeepsTheStandardFoldersInItsHome(shell: HostShell) throws {
        let folders = try Self.folders(shell: shell, home: "/home/me", variables: [:])

        #expect(folders == RemoteToolFolders(
            claude: "/home/me/.claude",
            codex: "/home/me/.codex",
            antigravity: "/home/me/.gemini/antigravity-cli",
            kiro: "/home/me/.kiro/sessions/cli",
            pi: "/home/me/.pi/agent/sessions"
        ))
    }

    @Test func piSessionFolderVariableComesFirst() throws {
        let folders = try Self.folders(shell: .sh, home: "/home/me", variables: [
            "PI_CODING_AGENT_SESSION_DIR": "/srv/pi", "PI_CODING_AGENT_DIR": "/opt/pi", "KIRO_HOME": "/opt/kiro",
        ])

        #expect(folders.pi == "/srv/pi")
        #expect(folders.kiro == "/opt/kiro/sessions/cli")
    }

    /// Pi's folder for a relative `sessionDir` depends on where Pi runs, which the lookup doesn't know.
    @Test func aRelativeSessionDirIsNotFollowed() {
        let output = """
            __JUSTSESSIONS_FOLDER__HOME=/home/me
            __JUSTSESSIONS_PI_SETTINGS_START__
            {"sessionDir": "sessions-here"}
            __JUSTSESSIONS_PI_SETTINGS_END__
            """

        #expect(RemoteToolFoldersLookup.folders(inOutput: output).pi == "/home/me/.pi/agent/sessions")
    }

    @Test func linesAShellProfilePrintsAreSkipped() {
        let output = "Welcome to Ubuntu\r\n__JUSTSESSIONS_FOLDER__HOME=/home/me\r\n__JUSTSESSIONS_FOLDER__CODEX_HOME=/srv/codex\r\n"

        #expect(RemoteToolFoldersLookup.folders(inOutput: output).codex == "/srv/codex")
    }

    @Test(arguments: ["", "Welcome to Ubuntu\n", "__JUSTSESSIONS_FOLDER__HOME=\n", "__JUSTSESSIONS_FOLDER__HOME=relative\n"])
    func withoutAnAbsoluteHomeTheStandardFoldersStay(output: String) {
        #expect(RemoteToolFoldersLookup.folders(inOutput: output) == .standard)
    }

    @Test func anUnreachableHostIsAConnectionProblem() {
        let runner = RemoteCommandRecorder().runner(answering: (255, "ssh: connect to host devbox port 22: Connection refused"))

        #expect(throws: RemoteSessionMirrorError.sshFailed(host: "devbox", problem: .refused)) {
            try RemoteToolFoldersLookup.folders(on: "devbox", runner: runner)
        }
    }

    @Test func aShellThatDoesNotAnswerKeepsTheStandardFolders() throws {
        let runner = RemoteHostCommandRunner { _, _, _ in nil }

        #expect(try RemoteToolFoldersLookup.folders(on: "devbox", runner: runner) == .standard)
    }

    @Test func runsThroughTheHostsLoginShell() {
        #expect(RemoteToolFoldersLookup.command(on: "devbox")
            == RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(RemoteToolFoldersLookup.script))", on: "devbox"))
    }

    private static func folders(shell: HostShell, home: String, variables: [String: String]) throws -> RemoteToolFolders {
        let result = try #require(BoundedProcessRunner.result(
            ofExecutable: shell.path,
            arguments: ["-c", RemoteToolFoldersLookup.script],
            environment: variables.merging(["HOME": home, "PATH": "/usr/bin:/bin"]) { $1 },
            includesStandardError: true,
            timeout: 10
        ))
        #expect(result.exitStatus == 0, "\(result.output)")
        return RemoteToolFoldersLookup.folders(inOutput: result.output)
    }
}
