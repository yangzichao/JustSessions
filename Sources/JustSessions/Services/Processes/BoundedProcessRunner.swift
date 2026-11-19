import Darwin
import Foundation

/// Output goes to a temporary file instead of a pipe: a pipe can fill up and stall the process,
/// or stay open forever when the process leaves a child behind.
enum BoundedProcessRunner {
    static func output(
        ofExecutable executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        includesStandardError: Bool = false,
        timeout: TimeInterval,
        cancelsWithTask: Bool = false
    ) -> String? {
        result(
            ofExecutable: executablePath,
            arguments: arguments,
            environment: environment,
            workingDirectory: workingDirectory,
            includesStandardError: includesStandardError,
            timeout: timeout,
            cancelsWithTask: cancelsWithTask
        )?.output
    }

    static func result(
        ofExecutable executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        includesStandardError: Bool = false,
        timeout: TimeInterval,
        cancelsWithTask: Bool = false
    ) -> (exitStatus: Int32, output: String)? {
        guard
            let outcome = outcome(
                ofExecutable: executablePath,
                arguments: arguments,
                environment: environment,
                workingDirectory: workingDirectory,
                includesStandardError: includesStandardError,
                timeout: timeout,
                cancelsWithTask: cancelsWithTask
            ), let exitStatus = outcome.exitStatus
        else { return nil }
        return (exitStatus, outcome.output)
    }

    static func outcome(
        ofExecutable executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        workingDirectory: URL? = nil,
        includesStandardError: Bool = false,
        timeout: TimeInterval,
        cancelsWithTask: Bool = false
    ) -> (exitStatus: Int32?, output: String)? {
        guard !cancelsWithTask || !Task.isCancelled else { return nil }
        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsessions-process-output-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputFile.path, contents: nil),
            let outputHandle = try? FileHandle(forWritingTo: outputFile)
        else { return nil }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputFile)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let environment { process.environment = environment }
        if let workingDirectory { process.currentDirectoryURL = workingDirectory }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = includesStandardError ? outputHandle : FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        let processID = process.processIdentifier
        let ownsProcessGroup = getpgid(processID) == processID
        let stopped = !waitForExit(finished, timeout: timeout, cancelsWithTask: cancelsWithTask)
        if stopped {
            if ownsProcessGroup {
                kill(-processID, SIGKILL)
            } else if process.isRunning {
                kill(processID, SIGKILL)
            }
            _ = finished.wait(timeout: .now() + 5)
        }

        guard let data = try? Data(contentsOf: outputFile) else { return nil }
        return (stopped ? nil : process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func waitForExit(_ finished: DispatchSemaphore, timeout: TimeInterval, cancelsWithTask: Bool) -> Bool {
        let deadline = DispatchTime.now() + timeout
        guard cancelsWithTask else { return finished.wait(timeout: deadline) == .success }
        while !Task.isCancelled {
            let nextCheck = DispatchTime.now() + .milliseconds(50)
            let waitUntil = nextCheck.uptimeNanoseconds < deadline.uptimeNanoseconds ? nextCheck : deadline
            if finished.wait(timeout: waitUntil) == .success { return true }
            if DispatchTime.now().uptimeNanoseconds >= deadline.uptimeNanoseconds { return false }
        }
        return false
    }
}
