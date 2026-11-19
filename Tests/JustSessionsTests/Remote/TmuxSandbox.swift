import Foundation

@testable import JustSessions

struct TmuxSandbox {
    static var installedTmuxDirectory: String? {
        ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
            .first(where: FileManager.default.isExecutableFile(atPath:))
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
    }

    let root: URL
    let project: URL
    let environment: [String: String]
    private let launchLog: URL
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

    func replaceCLI(withScript script: String) throws {
        try writeExecutableScript(script, to: root.appendingPathComponent("bin/claude"))
    }

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
