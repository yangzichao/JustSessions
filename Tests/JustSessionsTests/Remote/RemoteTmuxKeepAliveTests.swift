import Foundation
import Testing
@testable import JustSessions

/// Runs the remote tab's command against a real tmux on this Mac, with a private tmux server and home folder,
/// and stand-ins for the host's login shell and CLI. Skipped where tmux is not installed.
struct RemoteTmuxKeepAliveTests {
    @Test func cliKeepsRunningAfterDisconnectAndReopeningReattaches() throws {
        guard let tmuxPath = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
            .first(where: FileManager.default.isExecutableFile(atPath:)) else { return }
        let sandbox = try TmuxSandbox(tmuxDirectory: URL(fileURLWithPath: tmuxPath).deletingLastPathComponent().path)
        defer { sandbox.tearDown() }
        let tmuxName = TmuxSessionName.unique(for: .claude)
        let command = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: ["--resume", "abc"],
            tmuxSessionName: tmuxName
        )

        let firstClient = try sandbox.startClient(command)
        #expect(sandbox.waitUntil { sandbox.launchCount == 1 })
        #expect(sandbox.launchRecord?.hasSuffix("/Bob's paper\n--resume\nabc\n") == true)
        #expect(sandbox.hasTmuxSession(tmuxName))
        let options = sandbox.run("tmux show-options -t \(ShellQuoting.quoted(tmuxName))")
        #expect(options.contains("status off"))
        #expect(options.contains("mouse on"))
        #expect(options.contains("prefix None"))

        // The connection drops: the client goes away, the CLI stays.
        firstClient.terminate()
        firstClient.waitUntilExit()
        #expect(sandbox.hasTmuxSession(tmuxName))
        #expect(TmuxSessionName.appSessionNames(inListOutput: sandbox.run(RemoteTmuxCommands.listSessionsCommand)) == [tmuxName])

        // Opening it again attaches instead of starting the CLI a second time.
        let secondClient = try sandbox.startClient(command)
        Thread.sleep(forTimeInterval: 1.5)
        #expect(sandbox.launchCount == 1)
        secondClient.terminate()
        secondClient.waitUntilExit()

        let renamed = tmuxName + "-renamed"
        _ = sandbox.run(RemoteTmuxCommands.renameSessionCommand(from: tmuxName, to: renamed))
        #expect(sandbox.hasTmuxSession(renamed))
        _ = sandbox.run(RemoteTmuxCommands.killSessionCommand(renamed))
        #expect(sandbox.waitUntil { !sandbox.hasTmuxSession(renamed) })
    }

    @Test func hostWithoutTmuxRunsTheCLIDirectly() throws {
        let sandbox = try TmuxSandbox(tmuxDirectory: nil)
        defer { sandbox.tearDown() }
        let command = RemoteCLICommandBuilder.remoteCommand(
            provider: .claude,
            projectPath: sandbox.project.path,
            arguments: ["--resume", "abc"],
            tmuxSessionName: TmuxSessionName.unique(for: .claude)
        )
        _ = sandbox.run(command.replacingOccurrences(of: "exec claude", with: "exec claude-once"))
        #expect(sandbox.launchRecord?.hasSuffix("/Bob's paper\n--resume\nabc\n") == true)
    }
}

/// A temporary remote home: a login shell that runs its `-c` command, a `claude` that records how it was
/// started and then waits, and a private tmux server.
private struct TmuxSandbox {
    let root: URL
    let project: URL
    let environment: [String: String]
    private let launchLog: URL

    init(tmuxDirectory: String?) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tmux-\(UUID().uuidString.prefix(8))")
        project = root.appendingPathComponent("Bob's paper")
        launchLog = root.appendingPathComponent("launches.log")
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try Self.writeExecutable("#!/bin/sh\nshift\nexec /bin/sh -c \"$1\"\n", to: bin.appendingPathComponent("login-shell"))
        let record = "{ pwd -P; printf '%s\\n' \"$@\"; } >> '\(launchLog.path)'"
        try Self.writeExecutable("#!/bin/sh\n\(record)\nexec sleep 60\n", to: bin.appendingPathComponent("claude"))
        try Self.writeExecutable("#!/bin/sh\n\(record)\n", to: bin.appendingPathComponent("claude-once"))
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
    }

    private static func writeExecutable(_ script: String, to file: URL) throws {
        try script.write(to: file, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
    }
}
