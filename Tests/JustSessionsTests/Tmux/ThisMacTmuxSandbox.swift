import Darwin
import Foundation

@testable import JustSessions

struct ThisMacTmuxSandbox {
    let root: URL
    let project: URL
    let binaryDirectory: URL
    let environment: [String: String]
    let server: ThisMacTmuxServer

    static func make(tmuxPathOverride: String? = nil) throws -> ThisMacTmuxSandbox? {
        let bundledRuntime =
            tmuxPathOverride == nil
            ? ProcessInfo.processInfo.environment["JUSTSESSIONS_TEST_TMUX_RUNTIME"].map { URL(fileURLWithPath: $0) } : nil
        let candidatePaths =
            tmuxPathOverride.map { [$0] } ?? bundledRuntime.map { [$0.appendingPathComponent("bin/tmux").path] }
            ?? ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
        guard
            let tmuxPath =
                candidatePaths
                .first(where: FileManager.default.isExecutableFile(atPath:)),
            let versionOutput = BoundedProcessRunner.output(ofExecutable: tmuxPath, arguments: ["-V"], timeout: 5),
            ThisMacTmuxVersionCheck.isSupported(versionOutput: versionOutput)
        else { return nil }
        return try ThisMacTmuxSandbox(installedTmuxPath: tmuxPath, bundledRuntime: bundledRuntime)
    }

    private init(installedTmuxPath: String, bundledRuntime: URL?) throws {
        // A socket path has to stay short, so the folder sits right in the temporary folder.
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tmux-\(UUID().uuidString.prefix(8))")
        project = root.appendingPathComponent("Bob's paper")
        binaryDirectory = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binaryDirectory, withIntermediateDirectories: true)
        let tmuxLink = binaryDirectory.appendingPathComponent("tmux")
        try FileManager.default.createSymbolicLink(at: tmuxLink, withDestinationURL: URL(fileURLWithPath: installedTmuxPath))
        var sandboxEnvironment = [
            "HOME": root.path,
            "PATH": "\(binaryDirectory.path):/usr/bin:/bin",
            "TMUX_TMPDIR": root.path,
            "TERM": "xterm-256color",
            "LANG": "en_US.UTF-8",
        ]
        if let bundledRuntime {
            sandboxEnvironment["TERMINFO_DIRS"] = bundledRuntime.appendingPathComponent("share/terminfo").path + ":/usr/share/terminfo"
        }
        environment = sandboxEnvironment
        server = ThisMacTmuxServer(executablePath: tmuxLink.path, environment: environment)
    }

    var resolver: NativeCLICommandResolver {
        NativeCLICommandResolver(searchDirectories: [binaryDirectory.path], inheritedEnvironment: environment)
    }

    @discardableResult
    func writeExecutable(named name: String, script: String) throws -> URL {
        try writeExecutableScript(script, to: binaryDirectory.appendingPathComponent(name))
    }

    func cliCommand(_ executable: URL, arguments: [String] = [], extraEnvironment: [String: String] = [:]) -> NativeCLICommand {
        NativeCLICommand(
            executablePath: executable.path,
            arguments: arguments,
            workingDirectory: project.path,
            environment: environment.merging(extraEnvironment) { $1 }.map { "\($0.key)=\($0.value)" }.sorted()
        )
    }

    /// Runs a tab's command outside a tab; `script` gives the tmux client the terminal a tab would.
    func startClient(_ command: NativeCLICommand) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", command.executablePath] + command.arguments
        process.environment = command.environmentVariables
        process.currentDirectoryURL = URL(fileURLWithPath: command.workingDirectory)
        process.standardInput = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    func tmuxOutput(_ arguments: [String]) -> String {
        BoundedProcessRunner.output(
            ofExecutable: server.executablePath,
            arguments: ["-L", ThisMacTmuxServer.socketName] + arguments,
            environment: environment,
            timeout: 10
        ) ?? ""
    }

    @MainActor
    func waitUntil(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(120)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    @MainActor
    func checkTmuxVersionSoTabsRunInTmux(in store: ConversationStore) async -> Bool {
        store.refreshThisMac()
        return await waitUntil { !store.isScanningThisMac }
    }

    @MainActor
    func waitForPaneProcess(in store: ConversationStore, for tab: TerminalSession) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(120)
        while ContinuousClock.now < deadline {
            await store.lookUpTmuxPaneProcesses()
            if (tab.tmuxPaneProcessID ?? 0) > 0 { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return false
    }

    @MainActor
    func launchDiagnostics(for tab: TerminalSession) -> String {
        let terminalOutput = screenText(of: tab.terminalView)
        var descriptorLimit = rlimit()
        getrlimit(RLIMIT_NOFILE, &descriptorLimit)
        let openDescriptorCount = (0..<1024).filter { fcntl(Int32($0), F_GETFD) >= 0 }.count
        return "client PID: \(tab.processID), exited: \(tab.hasExited), exit code: \(String(describing: tab.exitCode)); "
            + "open descriptors below 1024: \(openDescriptorCount), limit: \(descriptorLimit.rlim_cur); "
            + "socket directory: \(root.path); terminal output: \(terminalOutput)"
    }

    func tearDown() {
        _ = tmuxOutput(["kill-server"])
        try? FileManager.default.removeItem(at: root)
    }
}
