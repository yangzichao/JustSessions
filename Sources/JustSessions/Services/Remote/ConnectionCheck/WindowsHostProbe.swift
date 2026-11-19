import Foundation

/// Tells a Windows host, whose OpenSSH server runs commands in `cmd.exe` or PowerShell, neither of which can run the
/// app's POSIX commands. Both print Windows' `OS` variable, `Windows_NT` whatever the language; a POSIX shell prints the
/// command's words instead.
enum WindowsHostProbe {
    /// `cmd.exe` expands `%OS%` and PowerShell `$env:OS`; each prints the other as typed. `sh` prints `%OS% :OS`.
    static let command = "echo %OS% $env:OS"

    static func isWindows(output: String) -> Bool {
        output.split(whereSeparator: \.isNewline).contains { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("Windows_NT")
        }
    }

    static func isWindows(_ host: String, runner: RemoteHostCommandRunner, timeout: TimeInterval) -> Bool {
        guard let result = runner.run(host, command, timeout),
            result.exitStatus != RemoteHostCommandRunner.connectionFailureExitStatus
        else { return false }
        return isWindows(output: result.output)
    }
}
