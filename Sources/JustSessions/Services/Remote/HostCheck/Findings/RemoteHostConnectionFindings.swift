import Foundation

enum RemoteHostConnectionFindings {
    static func connectionFinding(problem: SSHConnectionProblem?, host: String) -> HostCheckFinding {
        HostCheckFinding(
            id: .connection,
            status: problem == nil ? .passed : .problem,
            title: AppLocalization.string("Connection"),
            summary: problem?.explanation(host: host) ?? AppLocalization.string("Logged in to \(host)."),
            commandToRunYourself: RemoteHostCheckCommands.ssh(host, "true")
        )
    }

    static func shellStartupFinding(
        _ result: RemoteShellStartupCheckResult?,
        host: String,
        startup: RemoteShellStartup
    ) -> HostCheckFinding {
        let status: HostCheckFinding.Status
        let summary: String
        switch result?.outcome {
        case .interactiveStartupWorks:
            status = .passed
            summary = AppLocalization.string(
                "Commands start in \(host)'s login shell with its interactive startup files, as in your own terminal."
            )
        case .usesLoginShellOnly:
            status = .warning
            summary = AppLocalization.string(
                "\(host)'s interactive startup files start another program, so CLIs start without them. A PATH set only in those files doesn't reach the CLIs."
            )
        case .blocked:
            status = .problem
            summary = AppLocalization.string(
                "\(host)'s shell startup starts another program before the app's commands run, so sessions open that program instead of their CLI."
            )
        case nil:
            status = .warning
            summary = AppLocalization.string("The check of \(host)'s shell startup didn't finish.")
        }
        return HostCheckFinding(
            id: .shellStartup,
            status: status,
            title: AppLocalization.string("Shell startup"),
            summary: summary,
            hostOutput: result?.stoppedAt,
            commandToRunYourself: RemoteHostCheckCommands.shellStartup(host, startup: startup)
        )
    }
}
