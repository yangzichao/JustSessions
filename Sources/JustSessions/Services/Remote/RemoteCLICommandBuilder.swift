import Foundation

/// Builds the `ssh -t <host> …` command a terminal tab runs to open a session on a remote host.
struct RemoteCLICommandBuilder {
    let inheritedEnvironment: [String: String]

    init(inheritedEnvironment: [String: String] = ProcessInfo.processInfo.environment) {
        self.inheritedEnvironment = inheritedEnvironment
    }

    func command(
        host: String,
        provider: ConversationProvider,
        projectPath: String,
        arguments: [String]
    ) -> NativeCLICommand {
        var environment = TerminalColorEnvironment.removingColorDisablingVariables(from: inheritedEnvironment)
        environment["TERM"] = "xterm-256color"
        environment["COLORTERM"] = "truecolor"
        if environment["LANG"] == nil { environment["LANG"] = "en_US.UTF-8" }

        return NativeCLICommand(
            executablePath: "/usr/bin/ssh",
            arguments: ["-t", host, Self.remoteCommand(provider: provider, projectPath: projectPath, arguments: arguments)],
            workingDirectory: NSHomeDirectory(),
            environment: environment.map { "\($0.key)=\($0.value)" }.sorted()
        )
    }

    /// Runs the CLI through an interactive login shell, so the PATH set up in the host's shell profile
    /// (for example `~/.local/bin` or an nvm-managed `node`) is in effect.
    static func remoteCommand(provider: ConversationProvider, projectPath: String, arguments: [String]) -> String {
        let cliInvocation = ([executableName(for: provider)] + arguments.map(ShellQuoting.quoted)).joined(separator: " ")
        let innerCommand = "cd \(ShellQuoting.quoted(projectPath)) && exec \(cliInvocation)"
        return "exec \"$SHELL\" -lic \(ShellQuoting.quoted(innerCommand))"
    }

    static func executableName(for provider: ConversationProvider) -> String {
        switch provider {
        case .claude: "claude"
        case .codex: "codex"
        case .antigravity: "agy"
        }
    }
}
