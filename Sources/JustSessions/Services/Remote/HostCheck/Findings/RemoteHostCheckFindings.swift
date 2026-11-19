import Foundation

enum RemoteHostCheckFindings {
    static func findings(in output: RemoteHostCheckOutput, context: RemoteHostCheckContext) -> [HostCheckFinding] {
        var findings = [rsyncFinding(in: output, host: context.host)]
        guard output.reachedLoginShell else {
            findings.append(
                HostCheckFinding(
                    id: .loginShell,
                    status: .problem,
                    title: AppLocalization.string("Login shell"),
                    summary: AppLocalization.string(
                        "The check's commands didn't run in \(context.host)'s login shell, so nothing else could be checked. The app's commands start the same way, so sessions there can't start either."
                    ),
                    commandToRunYourself: RemoteHostCheckCommands.shellStartup(context.host, startup: context.shellStartup)
                ))
            return findings
        }
        findings.insert(systemFinding(in: output), at: 0)
        if let session = context.session {
            findings.append(folderFinding(in: output, projectPath: session.projectPath, host: context.host))
        }
        findings.append(RemoteHostTmuxFinding.finding(in: output, context: context))
        findings += RemoteHostCLIFindings.findings(in: output, context: context)
        if let pythonFinding = pythonFinding(in: output, context: context) {
            findings.append(pythonFinding)
        }
        return findings
    }

    static func systemFinding(in output: RemoteHostCheckOutput) -> HostCheckFinding {
        let summary = [output.text("os"), output.text("system")].compactMap { $0 }.joined(separator: " · ")
        let details = [
            output.text("shell").map { "SHELL=\($0)" },
            output.text("path").map { "PATH=\($0)" },
        ].compactMap { $0 }.joined(separator: "\n")
        return HostCheckFinding(
            id: .system,
            status: .note,
            title: AppLocalization.string("System"),
            summary: summary.isEmpty ? AppLocalization.string("Unknown") : summary,
            hostOutput: details.isEmpty ? nil : details
        )
    }

    static func rsyncFinding(in output: RemoteHostCheckOutput, host: String) -> HostCheckFinding {
        let command = RemoteHostCheckCommands.ssh(host, "command -v rsync && rsync --version")
        guard output.text("rsync-path") != nil else {
            return HostCheckFinding(
                id: .rsync,
                status: .problem,
                title: "rsync",
                summary: AppLocalization.string(
                    "rsync isn't installed on \(host), or isn't on the PATH of commands run over ssh, so its sessions can't be copied to this Mac."
                ),
                commandToRunYourself: command
            )
        }
        return HostCheckFinding(
            id: .rsync,
            status: .passed,
            title: "rsync",
            summary: AppLocalization.string("Copies \(host)'s sessions to this Mac."),
            hostOutput: output.text("rsync-version"),
            commandToRunYourself: command
        )
    }

    static func folderFinding(in output: RemoteHostCheckOutput, projectPath: String, host: String) -> HostCheckFinding {
        guard let folderExitStatus = output.exitStatus("folder-exit") else {
            return HostCheckFinding(
                id: .folder,
                status: .note,
                title: AppLocalization.string("Project folder"),
                summary: AppLocalization.string(
                    "\(projectPath) wasn't checked: the check can't pass a path with quotes, $, or backslashes to \(host)."
                )
            )
        }
        let exists = folderExitStatus == 0
        return HostCheckFinding(
            id: .folder,
            status: exists ? .passed : .problem,
            title: AppLocalization.string("Project folder"),
            summary: exists
                ? AppLocalization.string("\(projectPath) is a folder on \(host).")
                : AppLocalization.string(
                    "\(projectPath) isn't a folder on \(host), so the session can't start there. It may have been moved or deleted."
                ),
            hostOutput: output.text("folder"),
            commandToRunYourself: RemoteHostCheckCommands.isPlain(projectPath)
                ? RemoteHostCheckCommands.ssh(host, "ls -ld \(projectPath)")
                : nil
        )
    }

    static func pythonFinding(in output: RemoteHostCheckOutput, context: RemoteHostCheckContext) -> HostCheckFinding? {
        let toolsNeedingPython = context.programs.filter { program in
            RemoteSessionMirror.copiesSessionsWithPython3(for: program.provider)
                && (output.text(program.key + "-path") != nil || context.providersWithSessions.contains(program.provider))
        }.map(\.provider)
        guard !toolsNeedingPython.isEmpty else { return nil }
        let host = context.host
        let names = toolsNeedingPython.map(\.rawValue).joined(separator: ", ")
        let command = RemoteHostCheckCommands.inLoginShell(host, "echo import sqlite3 | python3", startup: context.shellStartup)
        guard output.text("python3-path") != nil else {
            return HostCheckFinding(
                id: .python3,
                status: .problem,
                title: "python3",
                summary: AppLocalization.string(
                    "Sessions of \(names) are copied with python3 on \(host), which isn't on its login shell's PATH."
                ),
                commandToRunYourself: command
            )
        }
        let canLoadSQLite = output.exitStatus("python3-sqlite3-exit") == 0
        return HostCheckFinding(
            id: .python3,
            status: canLoadSQLite ? .passed : .problem,
            title: "python3",
            summary: canLoadSQLite
                ? AppLocalization.string("Copies sessions of \(names).")
                : AppLocalization.string("python3 on \(host) can't load its sqlite3 module, so sessions of \(names) can't be copied."),
            hostOutput: output.text("python3-sqlite3"),
            commandToRunYourself: command
        )
    }
}
