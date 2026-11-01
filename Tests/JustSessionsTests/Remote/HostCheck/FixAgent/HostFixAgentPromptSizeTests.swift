import Foundation
import Testing
@testable import JustSessions

/// The prompt as the form first shows it, with every guide section, fits in the command that starts the agent on the
/// host, whichever tab the check came from and whichever CLI the agent is; see `HostFixAgentError.promptTooLong`.
struct HostFixAgentPromptSizeTests {
    private let report = HostCheckReport(
        host: "devbox",
        checkedAt: Date(timeIntervalSince1970: 0),
        thisMacSummary: "JustSessions 1.2.21 · macOS 27.0.1 · OpenSSH_10.0p2",
        findings: [
            HostCheckFinding(
                id: "tmux",
                status: .problem,
                title: "tmux",
                summary: "Started by another tmux version.",
                hostOutput: "protocol version mismatch (client 8, server 7)",
                commandToRunYourself: "ssh devbox 'tmux ls'"
            ),
            HostCheckFinding(
                id: "shell-startup",
                status: .warning,
                title: "Shell startup",
                summary: "The interactive startup files start another program.",
                commandToRunYourself: "ssh -t devbox 'env JUSTSESSIONS=1 \"$SHELL\" -lic \"echo Startup finished\"'"
            ),
        ],
        // As long as an ended tab's lines can be, with the quotes and backslashes a CLI's error may print.
        endedTabScreen: String(
            String(repeating: #"Error: can't read '/home/me/.config' (C:\path); run `tmux kill-server`"# + "\n", count: 60)
                .suffix(EndedTabScreenText.maximumCharacterCount)
        )
    )

    @Test(arguments: [nil] + ConversationProvider.allCases)
    func everyGuideSectionFitsWhicheverTabTheCheckCameFrom(checkedTabProvider: ConversationProvider?) {
        for shellStartup in [RemoteShellStartup.interactive, .loginOnly] {
            let facts = HostFixAgentHostFacts(
                host: "devbox",
                shellStartup: shellStartup,
                usesHostTmuxPrefix: false,
                runningTmuxSessionNames: ["justsessions-claude-new-1a2b3c4d", "justsessions-codex-0f9e8d7c"],
                tmuxServerProblem: nil,
                session: checkedTabProvider.map { HostCheckSession(provider: $0, projectPath: "/home/me/project") }
            )
            let message = HostFixAgentPrompt.message(
                task: HostFixAgentPrompt.task(for: report, facts: facts),
                machine: .checkedHost,
                host: "devbox",
                folder: "/home/me/project",
                guideSections: JustSessionsGuideSection.all,
                appVersion: "1.2.21"
            )
            for agentProvider in ConversationProvider.allCases {
                // Found by the login shell, the CLI's start command holds its arguments twice; see `RemoteCLIInvocation`.
                let remoteCommand = RemoteCLICommandBuilder.remoteCommand(
                    provider: agentProvider,
                    projectPath: "/home/me/project",
                    arguments: agentProvider.initialPromptArguments(message),
                    shellStartup: shellStartup,
                    cliLocation: .loginShell
                )
                #expect(
                    remoteCommand.utf8.count <= HostFixAgentError.longestRemoteCommandByteCount,
                    "\(agentProvider.rawValue) agent, \(shellStartup) shell: \(remoteCommand.utf8.count) bytes"
                )
            }
        }
    }
}
