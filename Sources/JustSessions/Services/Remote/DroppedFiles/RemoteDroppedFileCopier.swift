import Darwin
import Foundation

/// Copies a file dropped on a tab to the tab's SSH host, over the connection the app's background commands use, and
/// returns the file's absolute path there; see `RemoteDroppedFileCopyScript`. `ssh` reads the file itself, as its
/// standard input, and shares the file's read position with the app, so that position is how far the copy has gone.
struct RemoteDroppedFileCopier: Sendable {
    struct ProcessLaunch: Sendable {
        let executablePath: String
        let arguments: [String]
        let environment: [String: String]
    }

    static let stallTimeout: TimeInterval = 60
    static let progressInterval: TimeInterval = 0.2

    let processLaunch: @Sendable (_ host: String, _ hostCommand: String, _ connectionOptions: [String]) -> ProcessLaunch

    init(
        processLaunch: (@Sendable (_ host: String, _ hostCommand: String, _ connectionOptions: [String]) -> ProcessLaunch)? = nil
    ) {
        self.processLaunch =
            processLaunch ?? { host, hostCommand, connectionOptions in
                ProcessLaunch(
                    executablePath: "/usr/bin/ssh",
                    arguments: RemoteHostCommandRunner.sshArguments(
                        host: host,
                        command: hostCommand,
                        connectionSharingOptions: connectionOptions.isEmpty
                            ? SSHLoginConnections.shared.connectionOptions(for: host)
                            : connectionOptions
                    ),
                    environment: SSHProcessEnvironment.standard
                )
            }
    }

    func copy(
        _ fileURL: URL,
        to host: String,
        connectionOptions: [String],
        cancellation: RemoteDroppedFileCopyCancellation,
        progress: (_ copiedByteCount: Int64) -> Void
    ) throws -> String {
        let fileName = fileURL.lastPathComponent
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            throw RemoteDroppedFileCopyError.couldNotRead(fileName: fileName)
        }
        defer { try? fileHandle.close() }
        var fileStatus = stat()
        guard fstat(fileHandle.fileDescriptor, &fileStatus) == 0, fileStatus.st_mode & S_IFMT == S_IFREG else {
            throw RemoteDroppedFileCopyError.couldNotRead(fileName: fileName)
        }
        let byteCount = Int64(fileStatus.st_size)

        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsessions-dropped-file-copy-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputFile.path, contents: nil),
            let outputHandle = try? FileHandle(forWritingTo: outputFile)
        else { throw RemoteDroppedFileCopyError.couldNotRun(host: host) }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputFile)
        }

        let launch = processLaunch(
            host,
            RemoteDroppedFileCopyScript.command(fileName: fileName, byteCount: byteCount),
            connectionOptions
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launch.executablePath)
        process.arguments = launch.arguments
        process.environment = launch.environment
        process.standardInput = fileHandle
        process.standardOutput = outputHandle
        process.standardError = outputHandle
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { throw RemoteDroppedFileCopyError.couldNotRun(host: host) }
        if !cancellation.watch(process) { process.terminate() }
        defer { cancellation.stopWatching() }

        let didStall = waitForExit(
            of: process,
            finished: finished,
            readingFrom: fileHandle,
            byteCount: byteCount,
            progress: progress
        )
        if cancellation.isCancelled { throw CancellationError() }
        if didStall { throw RemoteDroppedFileCopyError.stalled(host: host) }

        let output = String(decoding: (try? Data(contentsOf: outputFile)) ?? Data(), as: UTF8.self)
        try Self.checkExitStatus(
            process.terminationStatus,
            output: output,
            host: host,
            fileName: fileName,
            didSendAnything: lseek(fileHandle.fileDescriptor, 0, SEEK_CUR) > 0
        )
        guard let folder = RemoteDroppedFileCopyScript.folder(inOutput: output) else {
            throw RemoteDroppedFileCopyError.failed(
                host: host,
                output: SSHConnectionProblem.tellingLine(inOutput: output) ?? "the host didn't say where the file went."
            )
        }
        progress(byteCount)
        return folder + "/" + fileName
    }

    private func waitForExit(
        of process: Process,
        finished: DispatchSemaphore,
        readingFrom fileHandle: FileHandle,
        byteCount: Int64,
        progress: (_ copiedByteCount: Int64) -> Void
    ) -> Bool {
        var copiedByteCount: Int64 = 0
        var lastAdvance = Date()
        while finished.wait(timeout: .now() + Self.progressInterval) == .timedOut {
            let readPosition = Int64(lseek(fileHandle.fileDescriptor, 0, SEEK_CUR))
            if readPosition > copiedByteCount {
                copiedByteCount = min(readPosition, byteCount)
                lastAdvance = Date()
            }
            progress(copiedByteCount)
            if copiedByteCount < byteCount, Date().timeIntervalSince(lastAdvance) > Self.stallTimeout {
                kill(process.processIdentifier, SIGKILL)
                finished.wait()
                return true
            }
        }
        return false
    }

    /// `ssh` reads the file only once it has connected, so a failure after `didSendAnything` that its output doesn't
    /// explain is a lost connection, as when the host stops or sleeps mid-copy.
    private static func checkExitStatus(
        _ exitStatus: Int32,
        output: String,
        host: String,
        fileName: String,
        didSendAnything: Bool
    ) throws {
        switch exitStatus {
        case 0:
            return
        case RemoteHostCommandRunner.connectionFailureExitStatus:
            var problem = SSHConnectionProblem(sshOutput: output)
            if didSendAnything, case .other = problem { problem = .connectionLost }
            throw RemoteDroppedFileCopyError.sshFailed(host: host, problem: problem)
        case RemoteDroppedFileCopyScript.ExitStatus.couldNotMakeFolder:
            throw RemoteDroppedFileCopyError.couldNotMakeFolder(host: host)
        case RemoteDroppedFileCopyScript.ExitStatus.couldNotWrite:
            throw RemoteDroppedFileCopyError.couldNotWrite(host: host, fileName: fileName)
        case RemoteDroppedFileCopyScript.ExitStatus.incomplete:
            throw RemoteDroppedFileCopyError.incomplete(host: host, fileName: fileName)
        default:
            throw RemoteDroppedFileCopyError.failed(
                host: host,
                output: SSHConnectionProblem.tellingLine(inOutput: output) ?? "exit status \(exitStatus)"
            )
        }
    }
}
