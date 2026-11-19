import Dispatch
import Foundation
import GhosttyTerminal

/// Stops a Ghostty tab from reading its process's output while too much of it waits to be parsed, as SwiftTerm's
/// `LocalProcess` does for a SwiftTerm tab. Ghostty's session takes output without limit, so without this a fast
/// process could fill memory. While the reading waits, the pseudo-terminal's buffer fills and the process blocks in
/// its writes, as in any terminal.
final class GhosttyOutputBackpressure: @unchecked Sendable {
    static let defaultHighWaterByteCount = 4 << 20
    static let defaultLowWaterByteCount = 1 << 20
    private static let waitSlice = DispatchTimeInterval.milliseconds(100)

    let highWaterByteCount: Int
    let lowWaterByteCount: Int
    private let session: InMemoryTerminalSession
    private let lock = NSLock()
    private let caughtUp = DispatchSemaphore(value: 0)
    private var bytesOnTheWayToGhostty = 0
    private var isWaiting = false
    private var hasStopped = false

    init(
        session: InMemoryTerminalSession,
        highWaterByteCount: Int = defaultHighWaterByteCount,
        lowWaterByteCount: Int = defaultLowWaterByteCount
    ) {
        self.session = session
        self.highWaterByteCount = highWaterByteCount
        self.lowWaterByteCount = lowWaterByteCount
        session.setOutputBacklogHandler(highWater: highWaterByteCount, lowWater: lowWaterByteCount) { [weak self] isBacklogged in
            if !isBacklogged { self?.wakeIfWaiting() }
        }
    }

    var unparsedByteCount: Int {
        lock.withLock { bytesOnTheWayToGhostty } + session.pendingOutputByteCount
    }

    var isWaitingForRoom: Bool {
        lock.withLock { isWaiting }
    }

    func waitForRoom() {
        guard unparsedByteCount >= highWaterByteCount else { return }
        while true {
            let hasStopped = lock.withLock {
                isWaiting = true
                return self.hasStopped
            }
            if hasStopped || unparsedByteCount <= lowWaterByteCount { break }
            _ = caughtUp.wait(timeout: .now() + Self.waitSlice)
        }
        lock.withLock { isWaiting = false }
    }

    func outputHandedToMainThread(byteCount: Int) {
        lock.withLock { bytesOnTheWayToGhostty += byteCount }
    }

    func outputPassedToGhostty(byteCount: Int) {
        let waitingBytes = lock.withLock {
            bytesOnTheWayToGhostty -= byteCount
            return bytesOnTheWayToGhostty
        }
        if waitingBytes + session.pendingOutputByteCount <= lowWaterByteCount { wakeIfWaiting() }
    }

    func stop() {
        lock.withLock { hasStopped = true }
        wakeIfWaiting()
    }

    private func wakeIfWaiting() {
        guard lock.withLock({ isWaiting }) else { return }
        caughtUp.signal()
    }
}
