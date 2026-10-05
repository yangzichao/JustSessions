import Foundation

/// Runs a start command chosen in the New session sheet, see `CLIStartCommands`, with the app's arguments after it.
/// A shell reads the command as you would type it, so quotes, `~`, and `NAME=value` in front work. `env` then runs the
/// CLI in the shell's place, so the tab's process is still the CLI's, which the lookups by process id depend on.
enum CLIStartCommandLine {
    static let thisMacShellPath = "/bin/sh"

    /// The command to run in place of the tool's executable, or nil when there is none or it is blank.
    static func customCommand(_ startCommand: String?) -> String? {
        guard let command = startCommand.map(CLIStartCommands.normalizedCommand), !command.isEmpty else { return nil }
        return command
    }

    /// The arguments of `/bin/sh` on this Mac: `-c 'exec /usr/bin/env <command> "$@"' sh <arguments>…`. The app's
    /// arguments reach the CLI as they are, without quoting.
    static func thisMacShellArguments(startCommand: String, arguments: [String]) -> [String] {
        ["-c", "exec /usr/bin/env \(startCommand) \"$@\"", "sh"] + arguments
    }

    /// What an SSH host's login shell runs: `env <command> 'argument'…`. `env` is found on the host's PATH.
    static func remoteInvocation(startCommand: String, arguments: [String]) -> String {
        (["env", startCommand] + arguments.map(ShellQuoting.quoted)).joined(separator: " ")
    }
}
