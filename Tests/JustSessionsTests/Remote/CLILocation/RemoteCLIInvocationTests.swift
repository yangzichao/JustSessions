import Foundation
import Testing

@testable import JustSessions

struct RemoteCLIInvocationTests {
    enum LoginShell: String, CaseIterable {
        case bash = "/bin/bash"
        case zsh = "/bin/zsh"

        var startupFileName: String {
            switch self {
            case .bash: ".bash_profile"
            case .zsh: ".zshrc"
            }
        }
    }

    struct Launch {
        let arguments: [String]
        let parentCommand: String
        let programsRunBesideTheCLI: [String]
    }

    @Test(arguments: LoginShell.allCases)
    func anAliasRunsWithItsArguments(shell: LoginShell) throws {
        let launch = try launch(
            in: shell,
            startup: { cli in "alias claude='\(cli) --from-alias'" },
            cliOnPath: false
        )

        #expect(launch.arguments == ["--from-alias", "--resume", "id with space"])
    }

    @Test(arguments: LoginShell.allCases)
    func aFunctionRunsWithItsArguments(shell: LoginShell) throws {
        let launch = try launch(
            in: shell,
            startup: { cli in "claude() { '\(cli)' --from-function \"$@\"; }" },
            cliOnPath: false
        )

        #expect(launch.arguments == ["--from-function", "--resume", "id with space"])
    }

    @Test(arguments: LoginShell.allCases)
    func anAliasInFrontOfTheProgramStillRuns(shell: LoginShell) throws {
        let launch = try launch(in: shell, startup: { _ in "alias claude='claude --from-alias'" }, cliOnPath: true)

        #expect(launch.arguments == ["--from-alias", "--resume", "id with space"])
    }

    @Test(arguments: LoginShell.allCases)
    func aProgramOnThePathTakesTheShellsPlace(shell: LoginShell) throws {
        let launch = try launch(in: shell, startup: { _ in "" }, cliOnPath: true)

        #expect(launch.arguments == ["--resume", "id with space"])
        #expect(!launch.parentCommand.hasSuffix("bash"))
        #expect(!launch.parentCommand.hasSuffix("zsh"))
    }

    /// bash has no `functions`, so asking it for one ran a program of that name, or, on Ubuntu, which has none, the
    /// command-not-found handler, which added about 40 ms to every tab's start.
    @Test(arguments: LoginShell.allCases)
    func functionsAreAskedOfTheShellNotOfThePath(shell: LoginShell) throws {
        let launch = try launch(in: shell, startup: { _ in "" }, cliOnPath: true, programsBesideTheCLI: ["functions"])

        #expect(launch.arguments == ["--resume", "id with space"])
        #expect(launch.programsRunBesideTheCLI.isEmpty)
    }

    @Test func aCLIInAnInstallFolderStartsByItsPathWithItsFolderFirstOnThePath() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let installFolder = root.appendingPathComponent("home/.claude/local")
        let project = root.appendingPathComponent("Bob's paper")
        try FileManager.default.createDirectory(at: installFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        let cli = installFolder.appendingPathComponent("claude")
        try writeExecutableScript("#!/bin/sh\npwd -P\necho \"${PATH%%:*}\"\nprintf '%s\\n' \"$@\"\n", to: cli)

        let output = try #require(
            BoundedProcessRunner.output(
                ofExecutable: "/bin/sh",
                arguments: [
                    "-c",
                    RemoteCLICommandBuilder.remoteCommand(
                        provider: .claude,
                        projectPath: project.path,
                        arguments: ["--resume", "abc"],
                        cliLocation: .installed(path: cli.path)
                    ),
                ],
                environment: ["SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "/usr/bin:/bin"],
                timeout: 10
            ))

        let lines = output.split(separator: "\n").map(String.init)
        #expect(lines.first?.hasSuffix("/Bob's paper") == true)
        #expect(Array(lines.dropFirst()) == [installFolder.path, "--resume", "abc"])
    }

    @Test func aMissingFolderIsReportedOnceAndStartsNothing() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        try writeExecutableScript("#!/bin/sh\necho started\n", to: bin.appendingPathComponent("claude"))

        let result = try #require(
            BoundedProcessRunner.result(
                ofExecutable: "/bin/sh",
                arguments: [
                    "-c",
                    RemoteCLICommandBuilder.remoteCommand(
                        provider: .claude,
                        projectPath: root.appendingPathComponent("gone").path,
                        arguments: []
                    ),
                ],
                environment: ["SHELL": bin.appendingPathComponent("login-shell").path, "PATH": "\(bin.path):/usr/bin:/bin"],
                includesStandardError: true,
                timeout: 10
            ))

        #expect(result.exitStatus != 0)
        #expect(!result.output.contains("started"))
        #expect(result.output.components(separatedBy: "/gone").count == 2)
    }

    /// Starts `claude` with `--resume 'id with space'` in `shell`, whose startup file holds `startup(cliPath)`.
    /// The stand-in is on PATH only when `cliOnPath` is set, by the startup file, as macOS's `path_helper` puts the
    /// system's folders, which may have a real `claude`, ahead of an inherited PATH. Each of `programsBesideTheCLI` is a
    /// program in the stand-in's folder that notes when it runs.
    private func launch(
        in shell: LoginShell,
        startup: (_ cliPath: String) -> String,
        cliOnPath: Bool,
        programsBesideTheCLI: [String] = []
    ) throws -> Launch {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let project = root.appendingPathComponent("project")
        let cliFolder = root.appendingPathComponent("cli")
        for folder in [home, project, cliFolder] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let record = root.appendingPathComponent("launch")
        let cli = cliFolder.appendingPathComponent("claude")
        // The record is found from the stand-in's own path, so every case's stand-in is the same script, which macOS
        // checks only once; see `writeExecutableScript(_:to:)`.
        try writeExecutableScript(
            "#!/bin/sh\n{ ps -o comm= -p \"$PPID\"; printf '%s\\n' \"$@\"; } > \"${0%/*}/../\(record.lastPathComponent)\"\n",
            to: cli
        )
        let programsRun = root.appendingPathComponent("programs-run")
        for name in programsBesideTheCLI {
            try writeExecutableScript("#!/bin/sh\necho '\(name)' >> '\(programsRun.path)'\n", to: cliFolder.appendingPathComponent(name))
        }
        let pathLine = cliOnPath ? "export PATH='\(cliFolder.path)':\"$PATH\"\n" : ""
        try (pathLine + startup(cli.path) + "\n")
            .write(to: home.appendingPathComponent(shell.startupFileName), atomically: true, encoding: .utf8)

        _ = BoundedProcessRunner.output(
            ofExecutable: "/bin/sh",
            arguments: [
                "-c",
                RemoteCLICommandBuilder.remoteCommand(
                    provider: .claude,
                    projectPath: project.path,
                    arguments: ["--resume", "id with space"]
                ),
            ],
            environment: [
                "HOME": home.path,
                "ZDOTDIR": home.path,
                "SHELL": shell.rawValue,
                "PATH": "/usr/bin:/bin",
                "TERM": "dumb",
            ],
            timeout: 20
        )

        let lines = try String(contentsOf: record, encoding: .utf8).split(separator: "\n").map(String.init)
        let programsRunBesideTheCLI =
            (try? String(contentsOf: programsRun, encoding: .utf8))?
            .split(separator: "\n").map(String.init) ?? []
        return Launch(
            arguments: Array(lines.dropFirst()),
            parentCommand: lines.first?.trimmingCharacters(in: .whitespaces) ?? "",
            programsRunBesideTheCLI: programsRunBesideTheCLI
        )
    }
}
