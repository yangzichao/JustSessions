import Foundation

/// Appends JSONL lines from another thread until stopped, as a running CLI writes its log while the reader scans it.
final class ContinuousLogAppender: @unchecked Sendable {
    private let handle: FileHandle
    private let lock = NSLock()
    private var isStopped = false
    private let firstLineWritten = DispatchSemaphore(value: 0)
    private let finished = DispatchSemaphore(value: 0)
    /// Read only after `stop()`, which waits for the writing thread to finish.
    private(set) var appendedLineCount = 0

    init(file: URL) throws {
        handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
    }

    /// Returns once the first line is written, so whatever runs next overlaps the writes.
    func start() {
        Thread.detachNewThread { [self] in
            let line = Data("{\"type\":\"event\"}\n".utf8)
            while !lock.withLock({ isStopped }) {
                try? handle.write(contentsOf: line)
                appendedLineCount += 1
                if appendedLineCount == 1 { firstLineWritten.signal() }
            }
            finished.signal()
        }
        firstLineWritten.wait()
    }

    func stop() {
        lock.withLock { isStopped = true }
        finished.wait()
        try? handle.close()
    }
}
