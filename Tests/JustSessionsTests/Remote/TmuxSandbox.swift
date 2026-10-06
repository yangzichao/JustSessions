import Foundation
@testable import JustSessions

/// A temporary remote home: a login shell that runs its `-c` command, a `claude` that records how it was
/// started and then waits, and a private tmux server, which reads `tmuxConfiguration` as the home's `~/.tmux.conf`.
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

    init(tmuxDirectory: String?, tmuxConfiguration: String? = nil) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tmux-\(UUID().uuidString.prefix(8))")
        project = root.appendingPathComponent("Bob's paper")
        launchLog = root.appendingPathComponent("launches.log")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try writeExecutableScript("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        let record = "{ pwd -P; printf '%s\\n' \"$@\"; } >> '\(launchLog.path)'"
        try writeExecutableScript("#!/bin/sh\n\(record)\nexec sleep 60\n", to: bin.appendingPathComponent("claude"))
        try writeExecutableScript("#!/bin/sh\n\(record)\n", to: bin.appendingPathComponent("claude-once"))
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

    func run(_ command: String) -> String {
        BoundedProcessRunner.output(ofExecutable: "/bin/sh", arguments: ["-c", command], environment: environment, timeout: 10) ?? ""
    }

    func hasTmuxSession(_ name: String) -> Bool {
        BoundedProcessRunner.result(
            ofExecutable: "/bin/sh",
            arguments: ["-c", "tmux has-session -t \(ShellQuoting.quoted(name))"],
            environment: environment,
            timeout: 10
        )?.exitStatus == 0
    }

    func waitUntil(_ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 10)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }

    func tearDown() {
        _ = run("tmux kill-server 2>/dev/null; true")
        try? FileManager.default.removeItem(at: root)
    }}
