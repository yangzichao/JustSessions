import Foundation
import Testing

@testable import JustSessions

/// The parts of `RemoteTmuxAttachScript` a real tmux on this Mac can't show: which tmux versions get the options that
/// keep a failed CLI's pane, how its captured output is trimmed, and a tmux that can't reach its server.
@Suite(.oneTmuxSandboxAtATime)
struct RemoteTmuxAttachScriptTests {
    /// `remain-on-exit failed` came in tmux 3.2; an older one would show "Bad value" in the tab.
    @Test(arguments: [
        ("tmux 2.6", false), ("tmux 3.0a", false), ("tmux 3.1", false), ("tmux 3.1c", false),
        ("tmux 3.2", true), ("tmux 3.2a", true), ("tmux 3.4", true), ("tmux 3.10", true),
        ("tmux next-3.6", true), ("tmux openbsd-7.6", true),
    ])
    func keepsAFailedCLIsPaneFromTmux32(version: String, keepsPane: Bool) throws {
        let sandbox = try TmuxSandbox(tmuxDirectory: nil)
        defer { sandbox.tearDown() }
        // Answers `-V`, records what a new session is started with, and finds no session.
        try sandbox.addProgram(
            named: "tmux",
            script: """
                case $1 in
                -V) echo '\(version)' ;;
                new-session) printf '%s\\n' "$@" > "$HOME/new-session.arguments" ;;
                *) exit 1 ;;
                esac
                """)
        let command = RemoteTmuxAttachScript.command(
            sessionName: "justsessions-claude-new-1a2b3c4d",
            paneCommand: "exec claude",
            sessionOptions: ["set-option status off", "set-option mouse on"]
        )

        _ = sandbox.run(command)

        let arguments = try String(contentsOf: sandbox.root.appendingPathComponent("new-session.arguments"), encoding: .utf8)
        #expect(arguments.hasPrefix("new-session\n-A\n-s\njustsessions-claude-new-1a2b3c4d\nexec claude\n;\nset-option\nstatus\noff\n;\n"))
        #expect(arguments.contains("remain-on-exit") == keepsPane)
        #expect(arguments.contains("pane-died") == keepsPane)
    }

    /// As after tmux was upgraded on the host while its old server kept running: every tmux command fails at once.
    @Test func aTmuxThatCantReachItsServerEndsTheTabWithItsStatus() throws {
        let sandbox = try TmuxSandbox(tmuxDirectory: nil)
        defer { sandbox.tearDown() }
        try sandbox.addProgram(
            named: "tmux",
            script: """
                case $1 in
                -V) echo 'tmux 3.4' ;;
                *) echo 'protocol version mismatch (client 8, server 7)' >&2; exit 1 ;;
                esac
                """)
        let command = RemoteTmuxAttachScript.command(
            sessionName: "justsessions-claude-new-1a2b3c4d",
            paneCommand: "exec claude",
            sessionOptions: ["set-option status off"]
        )

        let result = try #require(
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh", arguments: ["-c", command + " 2>&1"], environment: sandbox.environment, timeout: 10
            ))

        #expect(result.exitStatus == 1)
        #expect(result.output.contains("protocol version mismatch (client 8, server 7)"))
    }

    @Test func capturedOutputLosesTrailingBlanksAndTmuxsDeadPaneLine() {
        let captured =
            [
                "Starting   ",
                "",
                "Pane is dead (as a CLI may say)",
                "env: node: No such file or directory\t",
                "",
                "",
                "Pane is dead (status 127, Tue Oct 13 12:37:11 2026)",
                "",
                "",
            ].joined(separator: "\n") + "\n"

        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "printf '%s' \"$1\" | awk \"$2\"", "sh", captured, RemoteTmuxAttachScript.capturedOutputFilter],
            timeout: 10
        )

        #expect(output == "Starting\n\nPane is dead (as a CLI may say)\nenv: node: No such file or directory\n")
    }

    @Test func aCLIThatPrintedNothingLeavesNothing() {
        let output = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: [
                "-c", "printf '\\n\\nPane is dead (status 1)\\n\\n' | awk \"$1\"", "sh", RemoteTmuxAttachScript.capturedOutputFilter,
            ],
            timeout: 10
        )

        #expect(output == "")
    }
}
