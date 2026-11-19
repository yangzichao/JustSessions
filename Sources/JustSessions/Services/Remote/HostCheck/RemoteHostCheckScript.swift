import Foundation

/// `rsync` is looked up before the login shell starts: `rsync` on this Mac starts the host's `rsync` through the shell
/// `ssh` runs a command in, without the login shell's startup. Everything else is looked up in the login shell the
/// app's commands use, see `RemoteShellStartup`, where the CLIs, `tmux`, and `python3` are found. Both parts run in
/// `sh`, as the login shell may be fish. That shell also reads the scripts inside the single quotes around them, where
/// fish reads a backslash differently, so the scripts have no backslash and no single quote, which quoting again
/// would turn into backslashes; values go in double quotes instead, see `doubleQuoted(_:)`.
enum RemoteHostCheckScript {
    static let marker = "@@JUSTSESSIONS-CHECK"
    static let versionTimeoutSeconds = 10
    static let stoppedAtTimeLimitStatus = 128 + SIGTERM

    static func command(
        startup: RemoteShellStartup,
        programs: [RemoteHostCheckProgram],
        projectPath: String?,
        versionTimeoutSeconds: Int = versionTimeoutSeconds
    ) -> String {
        let loginShellScript = loginShellScript(
            startup: startup,
            programs: programs,
            projectPath: projectPath,
            versionTimeoutSeconds: versionTimeoutSeconds
        )
        return "/usr/bin/env sh -c \(ShellQuoting.quoted(outsideLoginShellScript)); "
            + startup.command(running: "sh -c \(ShellQuoting.quoted(loginShellScript))")
    }

    static func doubleQuoted(_ value: String) -> String? {
        guard !value.contains(where: { "\"$`\\'\n".contains($0) }) else { return nil }
        return "\"\(value)\""
    }

    private static var markerFunction: String {
        "marker() { echo; echo \"\(marker) $1\"; }"
    }

    static var outsideLoginShellScript: String {
        """
        \(markerFunction)
        marker rsync-path
        command -v rsync
        marker rsync-version
        command -v rsync >/dev/null 2>&1 && rsync --version 2>&1 | head -n 1
        marker outside-login-shell-done
        """
    }

    static func loginShellScript(
        startup: RemoteShellStartup = .interactive,
        programs: [RemoteHostCheckProgram],
        projectPath: String?,
        versionTimeoutSeconds: Int = versionTimeoutSeconds
    ) -> String {
        var lines = [
            markerFunction,
            // Runs a command for at most the time limit, with its output in a file, so a CLI that waits for input or
            // leaves a process behind can't keep the SSH connection open; a stopped command's sleep holds no output.
            // Each `wait` drops what `sh` prints about a job ended by a signal, such as "Terminated: 15".
            "limited() {",
            "  limited_out=$(mktemp)",
            "  \"$@\" </dev/null >\"$limited_out\" 2>&1 &",
            "  limited_pid=$!",
            "  ( sleep \(versionTimeoutSeconds); kill \"$limited_pid\" 2>/dev/null ) </dev/null >/dev/null 2>&1 &",
            "  limited_watcher=$!",
            "  wait \"$limited_pid\" 2>/dev/null",
            "  limited_status=$?",
            "  kill \"$limited_watcher\" 2>/dev/null",
            "  wait \"$limited_watcher\" 2>/dev/null",
            "  head -n 5 \"$limited_out\"",
            "  rm -f \"$limited_out\"",
            "}",
            "marker shell",
            "echo \"$SHELL\"",
            "marker system",
            "uname -srm 2>&1",
            "marker os",
            "if [ -r /etc/os-release ]; then ( . /etc/os-release; echo \"${PRETTY_NAME:-$NAME}\" );"
                + " elif command -v sw_vers >/dev/null 2>&1; then echo \"$(sw_vers -productName) $(sw_vers -productVersion)\"; fi",
            "marker path",
            "echo \"$PATH\"",
            "marker tmux-path",
            "command -v tmux",
            "if command -v tmux >/dev/null 2>&1; then",
            "  marker tmux-version",
            "  tmux -V 2>&1",
            // The running server's own version. Its output goes to a file: a tmux server older than 3.2 keeps the
            // output of a newer client open, which would hold the connection.
            "  marker tmux-server",
            "  tmux_out=$(mktemp)",
            "  tmux display-message -p \"#{version}\" </dev/null >\"$tmux_out\" 2>&1",
            "  tmux_status=$?",
            "  cat \"$tmux_out\"",
            "  rm -f \"$tmux_out\"",
            "  marker tmux-server-exit",
            "  echo \"$tmux_status\"",
            "fi",
        ]
        for program in programs {
            guard let quotedProgram = doubleQuoted(program.program) else { continue }
            lines += [
                "marker \(program.key)-path",
                "program=\(quotedProgram)",
                "case $program in \"~/\"*) program=$HOME/${program#\"~/\"} ;; esac",
                "found=$(command -v \"$program\" 2>/dev/null) || found=",
                "echo \"$found\"",
            ]
            if program.source == .cliExecutable {
                lines += [
                    "if [ -n \"$found\" ]; then",
                    "  marker \(program.key)-version",
                    "  limited \(versionInvocation(of: program)) --version",
                    "  marker \(program.key)-version-exit",
                    "  echo \"$limited_status\"",
                ]
                if program.location == .loginShell {
                    lines += [
                        "else",
                        "  marker \(program.key)-version",
                        "  limited \"$SHELL\" \(startup.shellFlags) \"\(program.program) --version\"",
                        "  marker \(program.key)-version-exit",
                        "  echo \"$limited_status\"",
                    ]
                }
                lines.append("fi")
            }
        }
        lines += [
            "marker python3-path",
            "command -v python3",
            "if command -v python3 >/dev/null 2>&1; then",
            "  marker python3-sqlite3",
            "  echo \"import sqlite3; print(sqlite3.sqlite_version)\" | python3 2>&1 | tail -n 3",
            "  marker python3-sqlite3-exit",
            "  echo \"import sqlite3\" | python3 >/dev/null 2>&1; echo $?",
            "fi",
        ]
        if let quotedProjectPath = projectPath.flatMap(doubleQuoted) {
            lines += [
                "marker folder",
                "ls -ld -- \(quotedProjectPath) 2>&1",
                "marker folder-exit",
                "[ -d \(quotedProjectPath) ]; echo $?",
            ]
        }
        lines.append("marker done")
        return lines.joined(separator: "\n")
    }

    private static func versionInvocation(of program: RemoteHostCheckProgram) -> String {
        guard case .installed(let path) = program.location else { return "\"$found\"" }
        let folder = (path as NSString).deletingLastPathComponent
        return "env \"PATH=\(folder):$PATH\" \"$found\""
    }
}
