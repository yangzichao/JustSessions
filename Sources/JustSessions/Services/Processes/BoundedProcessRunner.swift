import Darwin
import Foundation

/// Runs a short-lived helper process and returns what it printed, giving up after a timeout.
/// Output goes to a temporary file instead of a pipe: a pipe can fill up and stall the process,
/// or stay open forever when the process leaves a child behind.
enum BoundedProcessRunner {
    /// Returns the output whatever the exit status, or nil when the process could not start or timed out.
    static func output(
        ofExecutable executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        includesStandardError: Bool = false,
        timeout: TimeInterval
    ) -> String? {
        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsessions-process-output-\(UUID().uuidString)")
        guard FileManager.default.createFile(atPath: outputFile.path, contents: nil),
              let outputHandle = try? FileHandle(forWritingTo: outputFile) else { return nil }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputFile)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        if let environment { process.environment = environment }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        process.standardError = includesStandardError ? outputHandle : FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
            return nil
        }

        guard let data = try? Data(contentsOf: outputFile) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
