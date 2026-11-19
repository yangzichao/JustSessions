import Foundation

enum RemoteHostCLIFindings {
    static func findings(in output: RemoteHostCheckOutput, context: RemoteHostCheckContext) -> [HostCheckFinding] {
        var findings: [HostCheckFinding] = []
        var unneededMissingProviders: [ConversationProvider] = []
        for program in context.programs {
            if let path = output.text(program.key + "-path") {
                findings.append(foundFinding(program, path: path, output: output, context: context))
            } else if program.location == .loginShell {
                findings.append(aliasOrFunctionFinding(program, output: output, context: context))
            } else if program.provider == context.session?.provider || context.providersWithSessions.contains(program.provider) {
                findings.append(missingFinding(program, context: context))
            } else {
                unneededMissingProviders.append(program.provider)
            }
        }
        if !unneededMissingProviders.isEmpty {
            let names = unneededMissingProviders.map(\.rawValue).joined(separator: ", ")
            findings.append(
                HostCheckFinding(
                    id: .otherCLIs,
                    status: .note,
                    title: AppLocalization.string("Other CLIs"),
                    summary: AppLocalization.string("Not found on \(context.host): \(names).")
                ))
        }
        return findings
    }

    private static func foundFinding(
        _ program: RemoteHostCheckProgram,
        path: String,
        output: RemoteHostCheckOutput,
        context: RemoteHostCheckContext
    ) -> HostCheckFinding {
        let versionOutput = output.text(program.key + "-version")
        let status: HostCheckFinding.Status
        let summary: String
        switch (program.source, output.exitStatus(program.key + "-version-exit")) {
        case (.customStartCommand, _):
            status = .passed
            summary = AppLocalization.string("Your start command's program, found at \(path).")
        case (.cliExecutable, 0):
            status = .passed
            summary = AppLocalization.string("Found at \(path).")
        case (.cliExecutable, RemoteHostCheckScript.stoppedAtTimeLimitStatus):
            status = .warning
            summary = AppLocalization.string(
                "Found at \(path), but it didn't print its version within \(RemoteHostCheckScript.versionTimeoutSeconds) seconds."
            )
        case (.cliExecutable, _):
            status = .warning
            summary = AppLocalization.string(
                "Found at \(path), but it failed when asked for its version, so it may fail to start sessions too."
            )
        }
        let installFolderNote =
            program.location == .installed(path: program.program)
            ? " " + AppLocalization.string("It isn't on the PATH of \(context.host)'s login shell, so tabs start it from this folder.")
            : ""
        return HostCheckFinding(
            id: .cli(program.provider),
            status: status,
            title: program.provider.rawValue,
            summary: summary + installFolderNote,
            hostOutput: versionOutput,
            commandToRunYourself: command(for: program, context: context)
        )
    }

    private static func aliasOrFunctionFinding(
        _ program: RemoteHostCheckProgram,
        output: RemoteHostCheckOutput,
        context: RemoteHostCheckContext
    ) -> HostCheckFinding {
        let found = AppLocalization.string(
            "\(program.program) is an alias or function in \(context.host)'s login shell. Tabs run it as typing \(program.program) there would."
        )
        let status: HostCheckFinding.Status
        let summary: String
        switch output.exitStatus(program.key + "-version-exit") {
        case 0:
            status = .passed
            summary = found
        case RemoteHostCheckScript.stoppedAtTimeLimitStatus:
            status = .warning
            summary =
                found + " "
                + AppLocalization.string(
                    "It didn't print its version within \(RemoteHostCheckScript.versionTimeoutSeconds) seconds."
                )
        default:
            status = .warning
            summary =
                found + " "
                + AppLocalization.string(
                    "It failed when asked for its version, so it may fail to start sessions too."
                )
        }
        return HostCheckFinding(
            id: .cli(program.provider),
            status: status,
            title: program.provider.rawValue,
            summary: summary,
            hostOutput: output.text(program.key + "-version"),
            commandToRunYourself: command(for: program, context: context)
        )
    }

    private static func missingFinding(_ program: RemoteHostCheckProgram, context: RemoteHostCheckContext) -> HostCheckFinding {
        let host = context.host
        let isTheSessionsTool = program.provider == context.session?.provider
        let summary =
            isTheSessionsTool
            ? AppLocalization.string(
                "\(program.program) isn't on the PATH of \(host)'s login shell, so this session can't start. If it's installed, add its folder to PATH in a startup file that shell reads."
            )
            : AppLocalization.string(
                "\(program.program) isn't on the PATH of \(host)'s login shell, so its sessions listed here can't resume. If it's installed, add its folder to PATH in a startup file that shell reads."
            )
        return HostCheckFinding(
            id: .cli(program.provider),
            status: isTheSessionsTool ? .problem : .warning,
            title: program.provider.rawValue,
            summary: summary,
            commandToRunYourself: command(for: program, context: context)
        )
    }

    private static func command(for program: RemoteHostCheckProgram, context: RemoteHostCheckContext) -> String? {
        guard RemoteHostCheckCommands.isPlain(program.program) else { return nil }
        let lookup = "command -v \(program.program)"
        return RemoteHostCheckCommands.inLoginShell(
            context.host,
            program.source == .cliExecutable ? "\(lookup) && \(program.program) --version" : lookup,
            startup: context.shellStartup
        )
    }
}
