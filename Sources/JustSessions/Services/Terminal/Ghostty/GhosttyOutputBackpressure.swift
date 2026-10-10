import Dispatch
import Foundation
import GhosttyTerminal

/// Stops a Ghostty tab from reading its process's output while too much of it waits to be parsed, as SwiftTerm's
/// `LocalProcess` does for a SwiftTerm tab. Ghostty's session takes output without limit, so without this a fast
/// process could fill memory. While the reading waits, the pseudo-terminal's buffer fills and the process blocks in
/// its writes, as in any terminal.
///
/// The output waiting is what the tab has handed to the main thread and not yet passed to Ghostty, plus what Ghostty
/// has not parsed yet.
final class GhosttyOutputBackpressure: @unchecked Sendable {
    /// Reading stops once this much output waits, as SwiftTerm's `LocalProcess` does.
    static let defaultHighWaterByteCount = 4 << 20
    /// Reading starts again once no more than this waits.
    static let defaultLowWaterByteCount = 1 << 20
    /// How long one wait lasts before the count is read again, in case a wake-up was missed.
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

    /// Output read from the process that Ghostty has not parsed yet.
    var unparsedByteCount: Int {
        lock.withLock { bytesOnTheWayToGhostty } + session.pendingOutputByteCount
    }

    /// Called before each read is handed on; returns once there is room for it. Blocks the calling thread, which must
    /// not be the main thread, while at least the high-water mark waits, until the low-water mark is reached.
    func waitForRoom() {
        guard unparsedByteCount >= highWaterByteCount else { return }
        while true {
            // Marked before the count is read, so a wake-up that comes in between is kept by the semaphore.
            let hasStopped = lock.withLock {
                isWaiting = true
                return self.hasStopped
            }
            if hasStopped || unparsedByteCount <= lowWaterByteCount { break }
            _ = caughtUp.wait(timeout: .now() + Self.waitSlice)
        }
        lock.withLock { isWaiting = false }
    }

    /// The tab handed `byteCount` bytes of output to the main thread, on their way to Ghostty.
    func outputHandedToMainThread(byteCount: Int) {
        lock.withLock { bytesOnTheWayToGhostty += byteCount }
    }

    /// The tab passed `byteCount` bytes of output to Ghostty's session.
    func outputPassedToGhostty(byteCount: Int) {
        let waitingBytes = lock.withLock {
            bytesOnTheWayToGhostty -= byteCount
            return bytesOnTheWayToGhostty
        }
        if waitingBytes + session.pendingOutputByteCount <= lowWaterByteCount { wakeIfWaiting() }
    }

    /// The tab stopped reading from its process, so nothing waits for room any more.
    func stop() {
        lock.withLock { hasStopped = true }
        wakeIfWaiting()
    }

    private func wakeIfWaiting() {
        guard lock.withLock({ isWaiting }) else { return }
        caughtUp.signal()
    }
}
