import Foundation

/// Finds where an SSH host keeps each tool's sessions as the tools find it there: from `CLAUDE_CONFIG_DIR`,
/// `CODEX_HOME`, `KIRO_HOME`, `PI_CODING_AGENT_SESSION_DIR`, `PI_CODING_AGENT_DIR`, and Pi's `sessionDir` setting, set
/// in the host's login shell. The host prints them, and this Mac works the folders out with the rules its own adapters
/// use. Only absolute paths, or ones under `~`, are followed; the folders' standard places stand in for the rest.
enum RemoteToolFoldersLookup {
    static let variableNames = [
        "CLAUDE_CONFIG_DIR", "CODEX_HOME", "KIRO_HOME", "PI_CODING_AGENT_SESSION_DIR", "PI_CODING_AGENT_DIR",
    ]
    static let linePrefix = "__JUSTSESSIONS_FOLDER__"
    static let piSettingsStart = "__JUSTSESSIONS_PI_SETTINGS_START__"
    static let piSettingsEnd = "__JUSTSESSIONS_PI_SETTINGS_END__"

    /// The standard folders when the host's shell printed nothing that can be read, as when it timed out.
    static func folders(on host: String, runner: RemoteHostCommandRunner) throws -> RemoteToolFolders {
        guard let result = runner.run(host, command(on: host), 30) else { return .standard }
        if result.exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            throw RemoteSessionMirrorError.sshFailed(host: host, problem: SSHConnectionProblem(sshOutput: result.output))
        }
        return folders(inOutput: result.output)
    }

    static func command(on host: String) -> String {
        RemoteCLICommandBuilder.loginShellCommand("sh -c \(ShellQuoting.quoted(script))", on: host)
    }

    /// POSIX `sh`. Prints `$HOME` and each variable made absolute, or empty, then Pi's settings file.
    static var script: String {
        let printedVariables = variableNames.map { name in
            "printf '\(linePrefix)\(name)=%s\\n\' \"$(absolute \"${\(name):-}\")\""
        }
        return ([
            #"absolute() { case $1 in /*) printf '%s' "$1" ;; '~') printf '%s' "$HOME" ;; '~/'*) printf '%s' "$HOME/${1#'~/'}" ;; esac; }"#,
            "printf '\(linePrefix)HOME=%s\\n' \"$HOME\"",
        ] + printedVariables + [
            #"agent=$(absolute "${PI_CODING_AGENT_DIR:-}"); [ -n "$agent" ] || agent="$HOME/.pi/agent""#,
            "echo \(piSettingsStart)",
            #"cat "$agent/settings.json" 2>/dev/null"#,
            "echo; echo \(piSettingsEnd)",
        ]).joined(separator: "\n")
    }

    /// Lines a shell profile prints come before the lookup's, and are skipped.
    static func folders(inOutput output: String) -> RemoteToolFolders {
        let lines = output.components(separatedBy: "\n").map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        var values: [String: String] = [:]
        for line in lines where line.hasPrefix(linePrefix) {
            let entry = line.dropFirst(linePrefix.count)
            guard let separator = entry.firstIndex(of: "=") else { continue }
            values[String(entry[..<separator])] = String(entry[entry.index(after: separator)...])
        }
        guard let home = values["HOME"], home.hasPrefix("/"), home.count > 1 else { return .standard }
        let environment = values.filter { variableNames.contains($0.key) && $0.value.hasPrefix("/") }
        let piSettings = piSettingsText(in: lines).map { Data($0.utf8) }

        let piPath = PiSessionsDirectory.standardPath(environment: environment, homeDirectory: home, settingsData: { _ in piSettings })
        return RemoteToolFolders(
            claude: ClaudeAdapter.standardConfigurationDirectory(environment: environment, homeDirectory: home).path,
            codex: CodexAdapter.standardCodexDirectory(environment: environment, homeDirectory: home).path,
            kiro: KiroAdapter.standardSessionsDirectory(environment: environment, homeDirectory: home).path,
            // A relative `sessionDir` is relative to a folder the lookup doesn't know.
            pi: piPath.hasPrefix("/")
                ? piPath
                : PiSessionsDirectory.standardPath(environment: environment, homeDirectory: home, settingsData: { _ in nil })
        )
    }

    private static func piSettingsText(in lines: [String]) -> String? {
        guard let start = lines.lastIndex(of: piSettingsStart),
              let end = lines[start...].firstIndex(of: piSettingsEnd) else { return nil }
        let text = lines[(start + 1)..<end].joined(separator: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }
}
