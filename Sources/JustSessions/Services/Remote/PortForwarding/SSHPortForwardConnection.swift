import Foundation

final class SSHPortForwardConnection: @unchecked Sendable {
    static let defaultStartTimeout = SSHConnectTimeout.plus(slowLoginAllowance)
    private static let slowLoginAllowance: TimeInterval = 20

    enum StartOutcome {
        case started(SSHPortForwardConnection)
        case failed(SSHConnectionProblem)
    }

    let host: String
    let controlPath: String
    let output: SSHLoginOutput
    private let directory: URL
    private let process: Process
    private let lock = NSLock()
    private var isEnding = false
    private var hasEnded = false
    private var onEndOnItsOwn: (@Sendable (SSHPortForwardConnection) -> Void)?

    private init(host: String, directory: URL, output: SSHLoginOutput, process: Process) {
        self.host = host
        self.directory = directory
        controlPath = SSHLoginConnections.controlPath(in: directory)
        self.output = output
        self.process = process
    }

    /// Whether forwards can be added: the master runs and listens. A master that ended removed its socket.
    var isOpen: Bool {
        process.isRunning && FileManager.default.fileExists(atPath: controlPath)
    }

    static func start(
        to host: String,
        sshExecutable: String = "/usr/bin/ssh",
        socketRoot: String = SSHConnectionSharing.socketRoot,
        timeout: TimeInterval = defaultStartTimeout,
        onEndOnItsOwn: @escaping @Sendable (SSHPortForwardConnection) -> Void
    ) -> StartOutcome {
        guard let directory = SSHSocketDirectory.makePortForwardDirectory(at: socketRoot),
            let output = SSHLoginOutput(file: directory.appendingPathComponent("ssh-output")),
            let outputHandle = output.makeWritingHandle()
        else {
            return .failed(.other(sshMessage: "The app could not make a private folder for the connection in /tmp."))
        }
        defer { try? outputHandle.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sshExecutable)
        process.environment = SSHProcessEnvironment.standard
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = outputHandle
        let connection = SSHPortForwardConnection(host: host, directory: directory, output: output, process: process)
        process.arguments = SSHPortForwardCommands.connectionArguments(host: host, controlPath: connection.controlPath)
        process.terminationHandler = { process in
            process.terminationHandler = nil
            connection.processEnded()
        }
        do { try process.run() } catch {
            try? FileManager.default.removeItem(at: directory)
            return .failed(.other(sshMessage: "The app could not start ssh."))
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, !FileManager.default.fileExists(atPath: connection.controlPath), Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if connection.isOpen, connection.watchForEndOnItsOwn(onEndOnItsOwn) { return .started(connection) }
        let timedOut = process.isRunning
        let printed = output.all
        connection.end()
        return .failed(timedOut ? .noAnswer : SSHConnectionProblem(sshOutput: printed))
    }

    private func watchForEndOnItsOwn(_ onEndOnItsOwn: @escaping @Sendable (SSHPortForwardConnection) -> Void) -> Bool {
        lock.withLock {
            guard !hasEnded else { return false }
            self.onEndOnItsOwn = onEndOnItsOwn
            return true
        }
    }

    func end() {
        lock.withLock {
            isEnding = true
            onEndOnItsOwn = nil
        }
        if process.isRunning { process.terminate() }
        let deadline = Date().addingTimeInterval(2)
        while process.isRunning, Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        try? FileManager.default.removeItem(at: directory)
    }

    private func processEnded() {
        let onEndOnItsOwn: (@Sendable (SSHPortForwardConnection) -> Void)? = lock.withLock {
            hasEnded = true
            defer { self.onEndOnItsOwn = nil }
            return isEnding ? nil : self.onEndOnItsOwn
        }
        guard let onEndOnItsOwn else { return }
        try? FileManager.default.removeItem(at: directory)
        onEndOnItsOwn(self)
    }

    static func closeConnectionsOfEndedApps(
        socketRoot: String = SSHConnectionSharing.socketRoot,
        close: @Sendable (_ host: String, _ controlPath: String) -> Void = SSHLoginConnections.closeMaster
    ) {
        for directory in SSHSocketDirectory.portForwardDirectoriesOfEndedProcesses(at: socketRoot) {
            let controlPath = SSHLoginConnections.controlPath(in: directory)
            // `ssh -O exit` needs a destination, but the socket alone picks the master.
            if FileManager.default.fileExists(atPath: controlPath) { close("left-by-ended-app", controlPath) }
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
