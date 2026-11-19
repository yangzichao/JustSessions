import Foundation

/// This Mac's side of a host check's report: the app, macOS, and the `ssh` every SSH command runs.
enum HostCheckThisMacSummary {
    /// Such as "JustSessions 1.2.10 · macOS 26.0.1 · OpenSSH_10.3p1". `ssh -V` prints its version on standard error,
    /// followed by its TLS library's.
    static func current() -> String {
        let environment = FeedbackEnvironment.current.summary
        guard
            let output = BoundedProcessRunner.output(
                ofExecutable: "/usr/bin/ssh",
                arguments: ["-V"],
                includesStandardError: true,
                timeout: 5
            ), let sshVersion = output.split(separator: ",").first?.trimmingCharacters(in: .whitespacesAndNewlines),
            !sshVersion.isEmpty
        else { return environment }
        return "\(environment) · \(sshVersion)"
    }
}
