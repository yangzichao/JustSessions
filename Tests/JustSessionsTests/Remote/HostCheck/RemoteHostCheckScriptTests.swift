import Foundation
import Testing

@testable import JustSessions

struct RemoteHostCheckScriptTests {
    @Test func theScriptsHaveNoBackslashOrSingleQuoteForFishToReadDifferently() {
        let programs = RemoteHostCheckProgram.all { $0 == .claude ? "~/bin/claude-wrapper --fast" : nil }
        let loginShellScript = RemoteHostCheckScript.loginShellScript(programs: programs, projectPath: "/home/me/my project")
        for script in [RemoteHostCheckScript.outsideLoginShellScript, loginShellScript] {
            #expect(!script.contains("\\"))
            #expect(!script.contains("'"))
        }
    }

    @Test func valuesWithCharactersShReadsInsideDoubleQuotesAreNotQuoted() {
        #expect(RemoteHostCheckScript.doubleQuoted("/home/me/my project") == "\"/home/me/my project\"")
        for value in ["/home/me/it's", "/home/$USER", "/home/me/a\"b", "/home/me/a`b`", "/home/me/a\\b", "a\nb"] {
            #expect(RemoteHostCheckScript.doubleQuoted(value) == nil)
        }
        let unquotable = RemoteHostCheckScript.loginShellScript(programs: [], projectPath: "/home/me/it's")
        #expect(!unquotable.contains("marker folder"))
    }

    @Test func runsEachLookupInTheRightShellAndKeepsTheConnectionFreeOfSlowCLIs() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let loginShell = bin.appendingPathComponent("login-shell")
        try writeTimedStandIn("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: loginShell)
        try writeTimedStandIn("#!/bin/sh\necho \"rsync  version 3.2.7  protocol version 31\"\n", to: bin.appendingPathComponent("rsync"))
        try writeTimedStandIn(
            """
            #!/bin/sh
            case "$1" in
            -V) echo "tmux 3.4" ;;
            display-message) echo "no server running on /tmp/tmux-501/default" >&2; exit 1 ;;
            esac
            """,
            to: bin.appendingPathComponent("tmux")
        )
        try writeTimedStandIn("#!/bin/sh\necho \"codex-cli 0.50.0\"\n", to: bin.appendingPathComponent("codex"))
        try writeTimedStandIn(
            "#!/bin/sh\necho \"env: node: No such file or directory\" >&2\nexit 127\n",
            to: bin.appendingPathComponent("opencode")
        )
        try writeTimedStandIn("#!/bin/sh\nexec sleep 600\n", to: bin.appendingPathComponent("pi"))
        try writeTimedStandIn("#!/bin/sh\ncat >/dev/null\necho 3.45.1\n", to: bin.appendingPathComponent("python3"))
        let programs = RemoteHostCheckProgram.all { _ in nil }
        let command = RemoteHostCheckScript.command(
            startup: .interactive,
            programs: programs,
            projectPath: root.path
        )

        let started = Date()
        let result = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", command],
            environment: ["HOME": root.path, "SHELL": loginShell.path, "PATH": "\(bin.path):/usr/bin:/bin"],
            includesStandardError: true,
            timeout: 120
        )

        let output = RemoteHostCheckOutput(try #require(result).output)
        #expect(Date().timeIntervalSince(started) < 300)
        #expect(output.text("rsync-path") == bin.appendingPathComponent("rsync").path)
        #expect(output.text("outside-login-shell-done") == nil)
        #expect(output.reachedLoginShell)
        #expect(output.text("shell") == loginShell.path)
        #expect(output.text("tmux-version") == "tmux 3.4")
        #expect(output.text("tmux-server") == "no server running on /tmp/tmux-501/default")
        #expect(output.exitStatus("tmux-server-exit") == 1)
        #expect(output.text("cli-codex-version") == "codex-cli 0.50.0")
        #expect(output.exitStatus("cli-codex-version-exit") == 0)
        #expect(output.text("cli-opencode-version") == "env: node: No such file or directory")
        #expect(output.exitStatus("cli-opencode-version-exit") == 127)
        #expect(output.exitStatus("cli-pi-version-exit") == RemoteHostCheckScript.stoppedAtTimeLimitStatus)
        #expect(output.text("cli-claude-path") == nil)
        #expect(output.text("cli-claude-version-exit") == nil)
        #expect(output.text("python3-sqlite3") == "3.45.1")
        #expect(output.exitStatus("python3-sqlite3-exit") == 0)
        #expect(output.exitStatus("folder-exit") == 0)
        #expect(output.textsByKey["done"] != nil)
    }

    @Test func aMissingFolderAndAMissingTmuxAreAnswered() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let loginShell = try writeExecutableScript(
            "#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n",
            to: root.appendingPathComponent("login-shell")
        )
        let command = RemoteHostCheckScript.command(
            startup: .loginOnly,
            programs: [],
            projectPath: root.appendingPathComponent("moved away").path
        )

        let result = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", command],
            environment: ["HOME": root.path, "SHELL": loginShell.path, "PATH": "/usr/bin:/bin"],
            includesStandardError: true,
            timeout: 20
        )

        let output = RemoteHostCheckOutput(try #require(result).output)
        #expect(output.text("tmux-path") == nil)
        #expect(output.text("tmux-version") == nil)
        #expect(output.exitStatus("folder-exit") == 1)
        #expect(output.text("folder")?.contains("No such file or directory") == true)
    }

    @Test func asksEachCLIForItsVersionWhereTabsStartIt() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let installFolder = root.appendingPathComponent(".claude/local")
        try FileManager.default.createDirectory(at: installFolder, withIntermediateDirectories: true)
        let loginShell = try writeExecutableScript(
            "#!/bin/sh\nshift\nexec /bin/sh -c \"pi() { echo pi-from-function; }; $1\"\n",
            to: root.appendingPathComponent("login-shell")
        )
        let claude = try writeExecutableScript(
            "#!/bin/sh\necho \"${PATH%%:*}\"\n",
            to: installFolder.appendingPathComponent("claude")
        )
        let programs = RemoteHostCheckProgram.all { _ in nil }.map {
            $0.located(by: [.claude: .installed(path: claude.path), .pi: .loginShell])
        }
        let command = RemoteHostCheckScript.command(startup: .interactive, programs: programs, projectPath: nil)

        let result = BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", command],
            environment: ["HOME": root.path, "SHELL": loginShell.path, "PATH": "/usr/bin:/bin"],
            includesStandardError: true,
            timeout: 20
        )

        let output = RemoteHostCheckOutput(try #require(result).output)
        #expect(output.text("cli-claude-path") == claude.path)
        #expect(output.text("cli-claude-version") == installFolder.path)
        #expect(output.exitStatus("cli-claude-version-exit") == 0)
        #expect(output.text("cli-pi-path") == nil)
        #expect(output.text("cli-pi-version") == "pi-from-function")
        #expect(output.exitStatus("cli-pi-version-exit") == 0)
        #expect(output.text("cli-codex-version-exit") == nil)
    }
}
