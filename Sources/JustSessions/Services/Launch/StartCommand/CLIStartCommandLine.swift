import Foundation

enum CLIStartCommandLine {
    static let thisMacShellPath = "/bin/sh"

    static func customCommand(_ startCommand: String?) -> String? {
        guard let command = startCommand.map(CLIStartCommands.normalizedCommand), !command.isEmpty else { return nil }
        return command
    }

    static func thisMacShellArguments(startCommand: String, arguments: [String]) -> [String] {
        ["-c", "exec /usr/bin/env \(startCommand) \"$@\"", "sh"] + arguments
    }

    static func remoteInvocation(startCommand: String, arguments: [String]) -> String {
        remoteInvocation(startCommand: startCommand, quotedArguments: arguments.map(ShellQuoting.quoted))
    }

    static func remoteInvocation(startCommand: String, quotedArguments: [String]) -> String {
        (["env", startCommand] + quotedArguments).joined(separator: " ")
    }
}
