import Foundation

/// Waits for processes on this Mac to exit, whether or not the app started them.
enum ProcessExitWaiting {
    /// Blocks until none of the processes runs, or until `timeout` has passed. Returns whether they all exited. For
    /// background work only.
    @discardableResult
    static func waitUntilExited(_ processIDs: Set<Int32>, timeout: TimeInterval, pollInterval: TimeInterval = 0.05) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while processIDs.contains(where: RunningProcessInfo.isRunning) {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return true
    }
}
