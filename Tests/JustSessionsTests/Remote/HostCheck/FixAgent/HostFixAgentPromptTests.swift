import Foundation
import Testing
@testable import JustSessions

struct HostFixAgentPromptTests {
    private let report = HostCheckReport(
        host: "devbox",
        checkedAt: Date(timeIntervalSince1970: 0),
        thisMacSummary: "JustSessions 1.2.11",
        findings: [
            HostCheckFinding(
                id: "tmux",
                status: .problem,
                title: "tmux",
                summary: "Started by another tmux version.",
                hostOutput: "protocol version mismatch (client 8, server 7)",
                commandToRunYourself: "ssh devbox 'tmux ls'"
            ),
        ],
        endedTabScreen: "[exited]"
    )

    private func facts(
        tmuxServerProblem: String? = nil,
        runningTmuxSessionNames: Set<String>? = ["justsessions-claude-new-1a2b3c4d"]
    ) -> HostFixAgentHostFacts {
        HostFixAgentHostFacts(
            host: "devbox",
            shellStartup: .interactive,
            usesHostTmuxPrefix: false,
            runningTmuxSessionNames: runningTmuxSessionNames,
            tmuxServerProblem: tmuxServerProblem,
            session: HostCheckSession(provider: .codex, projectPath: "/srv/project")
        )
    }

    @Test func theTaskHasTheReportHowTheAppUsesTheHostAndTheRules() {
        let task = HostFixAgentPrompt.task(for: report, facts: facts())

        #expect(task.hasPrefix("Fix what JustSessions' host check found on devbox.\n"))
        #expect(task.contains(report.plainText.trimmingCharacters(in: .newlines)))
        #expect(task.contains("exec /usr/bin/env JUSTSESSIONS=1 \"$SHELL\" -lic '<command>'"))
        // The parts of the tab command the app really runs, for the tab the check came from.
        #expect(task.contains(RemoteCLICommandBuilder.remoteCommand(provider: .codex, projectPath: "/srv/project", arguments: [])))
        #expect(task.contains("`tmux new-session -A -s justsessions-codex-<session id> '<pane command>'`"))
        for option in RemoteTmuxSessionOptions.setOptionCommands(for: .codex, usingHostPrefix: false) {
            #expect(task.contains("`\(option)`"))
        }
        #expect(task.contains("`tmux list-panes -a -F '#{session_name}: #{pane_start_command}'`"))
        #expect(!task.contains("exec sh -c"))
        #expect(task.contains("justsessions-claude-new-1a2b3c4d"))
        #expect(task.contains("Before ending a tmux server, list its sessions with the tmux that started it"))
        #expect(task.contains(AppLinks.newGitHubIssueURL.absoluteString))
    }

    @Test func theTaskSaysWhenTheLastRefreshCouldntReachTheTmuxServer() {
        let task = HostFixAgentPrompt.task(for: report, facts: facts(tmuxServerProblem: "protocol version mismatch"))
        #expect(task.contains("The last refresh couldn't reach the tmux server; tmux printed: protocol version mismatch"))
    }

    @Test func theMessageSaysWhereTheAgentRunsAndEndsWithTheGuideSections() {
        let message = HostFixAgentPrompt.message(
            task: "The task.\n",
            machine: .checkedHost,
            host: "devbox",
            folder: "/home/me",
            guideSections: [.whenSomethingFailsOnSSHHost, .terminalPersistence],
            appVersion: "1.2.11",
            guideText: { $0 == .terminalPersistence ? nil : "### \($0.heading)\n\nWhat to do." }
        )

        #expect(message.hasPrefix("JustSessions started you on devbox, in /home/me, straight in the user's login shell rather than in tmux"))
        #expect(message.contains("\n\nThe task.\n\n## JustSessions' guides\n"))
        #expect(message.contains("https://github.com/yangzichao/JustSessions/tree/v1.2.11/docs/guides"))
        #expect(message.hasSuffix("""
            ### session-management.md: When something fails on an SSH host

            Source: https://github.com/yangzichao/JustSessions/blob/v1.2.11/docs/guides/session-management.md#when-something-fails-on-an-ssh-host

            What to do.

            """))
        // A section the app can't read is left out.
        #expect(!message.contains("Terminal persistence"))
    }

    @Test func anAgentOnThisMacIsToldToReachTheHostWithSSH() {
        let message = HostFixAgentPrompt.message(
            task: "The task.",
            machine: .thisMac,
            host: "devbox",
            folder: "/Users/me",
            guideSections: [],
            appVersion: "1.2.11-3-gabc1234"
        )
        #expect(message == """
            JustSessions started you on the user's Mac, in /Users/me, outside tmux. devbox is another machine: reach it with `ssh devbox`, as the check's "Run it yourself" commands do. JustSessions' own tmux on this Mac (`-L justsessions`) is not what the check is about.

            The task.

            """)
    }
}
