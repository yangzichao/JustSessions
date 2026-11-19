import Foundation

@testable import JustSessions

/// A temporary remote home: a login shell that runs its `-c` command, a `claude` that records how it was
/// started and then waits, and a private tmux server, which reads `tmuxConfiguration` as the home's `~/.tmux.conf`.
/// The login shell reads `loginShellStartup` first, as a host's startup files may define an alias or function.
struct TmuxSandbox {
    /// The folder of an installed tmux, or nil where none is, and tests that need one are skipped.
    static var installedTmuxDirectory: String? {
        ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
    }

    let root: URL
    let project: URL
    let environment: [String: String]
    private let launchLog: URL
    /// The line of the `claude` stand-in that records how it was started.
    private let recordLaunch: String

    init(tmuxDirectory: String?, tmuxConfiguration: String? = nil, loginShellStartup: String? = nil) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tmux-\(UUID().uuidString.prefix(8))")
        project = root.appendingPathComponent("Bob's paper")
        launchLog = root.appendingPathComponent("launches.log")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        if let loginShellStartup {
            let startupFile = root.appendingPathComponent("startup")
            try loginShellStartup.write(to: startupFile, atomically: true, encoding: .utf8)
            try writeExecutableScript(
                "#!/bin/sh\nshift\nexec /bin/sh -c \". '\(startupFile.path)'; $1\"\n",
                to: bin.appendingPathComponent("login-shell")
            )
        } else {
            try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        }
        // The log is found from the stand-in's own path, so every sandbox's stand-in is the same script, which macOS
        // checks only once; see `writeExecutableScript(_:to:)`.
        recordLaunch = "{ pwd -P; printf '%s\\n' \"$@\"; } >> \"${0%/*}/../\(launchLog.lastPathComponent)\""
        // It runs until a test or `tearDown()` ends it, as `ThisMacTmuxSandbox.writeExecutable` says.
        try writeExecutableScript("#!/bin/sh\n\(recordLaunch)\nexec sleep 600\n", to: bin.appendingPathComponent("claude"))
        if let tmuxConfiguration {
            try tmuxConfiguration.write(to: root.appendingPathComponent(".tmux.conf"), atomically: true, encoding: .utf8)
        }
        environment = [
            "HOME": root.path,
            "SHELL": bin.appendingPathComponent("login-shell").path,
            "PATH": ([bin.path, tmuxDirectory].compactMap { $0 } + ["/usr/bin", "/bin"]).joined(separator: ":"),
            "TMUX_TMPDIR": root.path,
            "TERM": "xterm-256color",
        ]
    }

    /// Makes the `claude` stand-in run `script` instead, for a test whose CLI behaves otherwise.
    func replaceCLI(withScript script: String) throws {
        try writeExecutableScript(script, to: root.appendingPathComponent("bin/claude"))
    }

    /// Makes the `claude` stand-in exit once it has recorded how it was started.
    func makeCLIExitAtOnce() throws {
        try replaceCLI(withScript: "#!/bin/sh\n\(recordLaunch)\n")
    }

    var launchRecord: String? { try? String(contentsOf: launchLog, encoding: .utf8) }
    var launchCount: Int { launchRecord?.components(separatedBy: "--resume").count.advanced(by: -1) ?? 0 }

    /// `script` gives the command a terminal, as `ssh -t` does.
    func startClient(_ command: String) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "/dev/null", "/bin/sh", "-c", command]
        process.environment = environment
        process.standardInput = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    /// Starts `command` as `startClient` does, writing what the terminal is sent to `outputFile` as it goes.
    func startClient(_ command: String, recordingOutputTo outputFile: URL) throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", "-F", outputFile.path, "/bin/sh", "-c", command]
        process.environment = environment
        process.standardInput = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        return process
    }

    /// Runs `command` in a terminal, as `startClient` does, until it exits, and returns what the terminal was sent.
    func runClient(_ command: String) throws -> (exitStatus: Int32, output: String) {
        let outputFile = root.appendingPathComponent("client-\(UUID().uuidString.prefix(8)).log")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        process.arguments = ["-q", outputFile.path, "/bin/sh", "-c", command]
        process.environment = environment
        process.standardInput = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        if !waitUntil({ !process.isRunning }) { process.terminate() }
        process.waitUntilExit()
        let output = (try? Data(contentsOf: outputFile)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return (process.terminationStatus, output)
    }

    /// A stand-in tool in the home's `bin` folder, first on the PATH, such as a tmux that answers as an older one.
    func addProgram(named name: String, script body: String) throws {
        try writeExecutableScript("#!/bin/sh\n\(body)\n", to: root.appendingPathComponent("bin").appendingPathComponent(name))
    }

    func run(_ command: String, timeout: TimeInterval = 10) -> String {
        BoundedProcessRunner.output(ofExecutable: "/bin/sh", arguments: ["-c", command], environment: environment, timeout: timeout) ?? ""
    }

    func hasTmuxSession(_ name: String) -> Bool {
        BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "tmux has-session -t \(ShellQuoting.quoted(name))"],
            environment: environment,
            timeout: 10
        )?.exitStatus == 0
    }

    /// Every caller waits for something to happen, so a passing test never waits out the deadline. It is long because
    /// tmux can take many seconds to start while other suites fill the machine, as on a CI runner.
    func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 120)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }

    func tearDown() {
        _ = run("tmux kill-server 2>/dev/null; true")
        try? FileManager.default.removeItem(at: root)
    }
}
