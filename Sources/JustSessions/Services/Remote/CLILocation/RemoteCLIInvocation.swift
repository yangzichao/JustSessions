import Foundation

/// How the commands the app runs in an SSH host's login shell, which may be fish, start a tool's CLI from where the
/// host's refresh found it. Like the rest of those commands, they use no `if`, loops, or `VAR=value` before a command.
enum RemoteCLIInvocation {
    /// Started by name, the CLI starts as typing the name would. A program on PATH replaces the shell, so the tab's
    /// process is the CLI's. An alias or function, which `exec` can't run, runs in the shell, with the alias's
    /// arguments. `command -v` gives a path only for a program no alias or function of bash, zsh, or dash stands in
    /// front of; fish's skips functions, where fish aliases live, so `functions` is asked too. Other shells have no
    /// `functions`, or one that prints only the functions `command -v` already named. `builtin` asks only the shell:
    /// bash would look for a `functions` program, and on Ubuntu its command-not-found handler then added about 40 ms
    /// to every tab's start.
    static func startCommand(
        executableName: String,
        location: RemoteCLILocation,
        projectPath: String,
        quotedArguments: [String]
    ) -> String {
        let folder = ShellQuoting.quoted(projectPath)
        let arguments = quotedArguments.map { " " + $0 }.joined()
        switch location {
        case .loginShell:
            return "cd \(folder) && command -v \(executableName) 2>/dev/null | grep -q \"^/\""
                + " && builtin functions \(executableName) 2>/dev/null | grep -c . | grep -qx 0"
                + " && exec \(executableName)\(arguments)"
                + "; cd \(folder) 2>/dev/null && \(executableName)\(arguments)"
        case .installed(let path):
            return "cd \(folder) && exec \(installedInvocation(path: path))\(arguments)"
        }
    }

    static func oneOffInvocation(executableName: String, location: RemoteCLILocation) -> String {
        switch location {
        case .loginShell: executableName
        case .installed(let path): installedInvocation(path: path)
        }
    }

    /// `env PATH='<folder>':"$PATH" '<path>'`. fish joins a quoted `$PATH` with colons, as other shells keep it.
    private static func installedInvocation(path: String) -> String {
        let folder = (path as NSString).deletingLastPathComponent
        return "env PATH=\(ShellQuoting.quoted(folder)):\"$PATH\" \(ShellQuoting.quoted(path))"
    }
}
