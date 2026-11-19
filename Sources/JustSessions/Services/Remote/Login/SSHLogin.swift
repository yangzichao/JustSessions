import Darwin
import Foundation

/// Logs in to a host for Connect…, as `ssh <host>` does in Terminal: it starts the host's master connection, and each
/// question `ssh` asks on the way, such as a password, a passphrase, a code, or whether to trust a new host key, is
/// asked in the app through `SSHAskpassRelay`. The master then waits in the background for the app's other
/// connections, and `SSHLoginConnections` keeps it.
struct SSHLogin: Sendable {
    /// Started by `ssh` for each question: this app's own executable.
    let askpassProgram: String
    let sshExecutable: String
    let socketRoot: String
    let connections: SSHLoginConnections
    let timeout: TimeInterval

    init(
        askpassProgram: String = Bundle.main.executablePath ?? CommandLine.arguments[0],
        sshExecutable: String = "/usr/bin/ssh",
        socketRoot: String = SSHConnectionSharing.socketRoot,
        connections: SSHLoginConnections = .shared,
        timeout: TimeInterval = 5 * 60
    ) {
        self.askpassProgram = askpassProgram
        self.sshExecutable = sshExecutable
        self.socketRoot = socketRoot
        self.connections = connections
        self.timeout = timeout
    }

    /// The master runs `true`, then stays open; see `SSHLoginConnections.persistence`. The background commands'
    /// connection settings apply, but the login may ask questions. Tabs go through it, and it, not the tab, decides
    /// whether their keystrokes are sent in batches; see `SSHKeystrokeTiming`.
    static func sshArguments(
        host: String,
        controlPath: String,
        keystrokeTimingOptions: [String] = SSHKeystrokeTiming.options
    ) -> [String] {
        [RemoteHostCommandRunner.noTerminalOption, "-o", "BatchMode=no"]
            + RemoteHostCommandRunner.connectionSettingOptions
            + keystrokeTimingOptions
            + [
                "-o", "ControlMaster=yes",
                "-o", "ControlPath=\(controlPath)",
                "-o", "ControlPersist=\(SSHLoginConnections.persistence)",
                host, "true",
            ]
    }

    /// `ask` returns what to answer, or nil when the question was cancelled. A question whose task is cancelled went
    /// away on its own, as a notice does once `ssh` is done with it.
    func logIn(to host: String, ask: @escaping @Sendable (SSHAskpassQuestion) async -> String?) async -> SSHLoginOutcome {
        guard let directory = SSHSocketDirectory.makeLoginDirectory(at: socketRoot),
            let output = SSHLoginOutput(file: directory.appendingPathComponent("ssh-output"))
        else {
            return .failed(.other(sshMessage: "The app could not make a private folder for the connection in /tmp."))
        }
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        let run = LoginRun()
        guard
            let server = SSHAskpassServer(
                socketPath: directory.appendingPathComponent("askpass").path,
                ask: { request in
                    let question = SSHAskpassQuestion(
                        host: host,
                        request: request,
                        context: output.newText(),
                        previousPrompt: run.notePrompt(request.prompt.trimmingCharacters(in: .whitespacesAndNewlines))
                    )
                    let answer = await ask(question)
                    if answer == nil, !Task.isCancelled { run.cancel() }
                    return SSHAskpassReply(answer: answer)
                })
        else {
            try? FileManager.default.removeItem(at: directory)
            return .failed(.other(sshMessage: "The app could not listen for the login's questions."))
        }

        let exitStatus = await runSSH(
            host: host,
            controlPath: controlPath,
            askpassSocket: server.socketPath,
            output: output,
            run: run
        )
        server.stop()
        let printed = output.all
        try? FileManager.default.removeItem(at: output.file)

        let outcome: SSHLoginOutcome
        if run.isCancelled {
            outcome = .cancelled
        } else if exitStatus == nil {
            outcome = .failed(.noAnswer)
        } else if exitStatus == RemoteHostCommandRunner.connectionFailureExitStatus {
            outcome = .failed(SSHConnectionProblem(sshOutput: printed))
        } else if FileManager.default.fileExists(atPath: controlPath) {
            outcome = .loggedIn
        } else {
            // Logged in, but the master did not stay, as when the host refuses sessions to share the connection.
            outcome = .failed(
                .other(
                    sshMessage: SSHConnectionProblem.tellingLine(inOutput: printed)
                        ?? "The connection closed after logging in."))
        }
        if outcome == .loggedIn {
            connections.add(directory, for: host)
        } else {
            try? FileManager.default.removeItem(at: directory)
        }
        return outcome
    }

    /// The exit status, or nil when `ssh` could not start, was cancelled, or ran past the timeout.
    private func runSSH(
        host: String,
        controlPath: String,
        askpassSocket: String,
        output: SSHLoginOutput,
        run: LoginRun
    ) async -> Int32? {
        guard let outputHandle = output.makeWritingHandle() else { return nil }
        defer { try? outputHandle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sshExecutable)
        process.arguments = Self.sshArguments(host: host, controlPath: controlPath)
        process.environment = SSHProcessEnvironment.standard.merging([
            "SSH_ASKPASS": askpassProgram,
            "SSH_ASKPASS_REQUIRE": "force",
            SSHAskpassRelay.socketEnvironmentVariable: askpassSocket,
        ]) { _, loginValue in loginValue }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = outputHandle

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                process.terminationHandler = { process in
                    continuation.resume(returning: run.isStopped ? nil : process.terminationStatus)
                }
                do { try process.run() } catch {
                    process.terminationHandler = nil
                    continuation.resume(returning: nil)
                    return
                }
                run.start(process)
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { run.stop() }
            }
        } onCancel: {
            run.cancel()
        }
    }

    /// The login's `ssh`, which a cancelled question, a cancelled task, or the timeout stops.
    private final class LoginRun: @unchecked Sendable {
        private let lock = NSLock()
        private var process: Process?
        private var wasCancelled = false
        private var wasStopped = false
        private var lastPrompt: String?

        var isCancelled: Bool { lock.withLock { wasCancelled } }
        var isStopped: Bool { lock.withLock { wasStopped } }

        /// Keeps `prompt` as the latest question's, and returns the one before it.
        func notePrompt(_ prompt: String) -> String? {
            lock.withLock {
                defer { lastPrompt = prompt }
                return lastPrompt
            }
        }

        func start(_ process: Process) {
            let stopsAtOnce = lock.withLock {
                self.process = process
                return wasStopped
            }
            if stopsAtOnce { process.terminate() }
        }

        func cancel() {
            lock.withLock { wasCancelled = true }
            stop()
        }

        func stop() {
            let process = lock.withLock {
                wasStopped = true
                return self.process
            }
            if let process, process.isRunning { process.terminate() }
        }
    }
}
