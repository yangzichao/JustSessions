import Foundation

final class RemoteDroppedFileCopyCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelledValue = false
    private var runningProcess: Process?

    var isCancelled: Bool { lock.withLock { isCancelledValue } }

    func cancel() {
        let process: Process? = lock.withLock {
            isCancelledValue = true
            return runningProcess
        }
        if let process, process.isRunning { process.terminate() }
    }

    func watch(_ process: Process) -> Bool {
        lock.withLock {
            guard !isCancelledValue else { return false }
            runningProcess = process
            return true
        }
    }

    func stopWatching() {
        lock.withLock { runningProcess = nil }
    }
}
