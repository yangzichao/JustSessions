import Foundation

enum ProcessExitWaiting {
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
