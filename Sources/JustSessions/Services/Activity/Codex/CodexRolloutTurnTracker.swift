import Foundation

/// Follows the session files of running Codex CLIs to tell whether each is in a turn. The first look at a file reads
/// its end, further back step by step until a turn event turns up; later looks read only what Codex appended since.
final class CodexRolloutTurnTracker: @unchecked Sendable {
    /// The most read at once. A file that grew more than this since the last look is looked at afresh.
    static let largestReadByteCount: UInt64 = 16 << 20
    /// How much of a file's end the first look reads, step by step. A turn that has written more than the last step
    /// since it started stays unknown until its next event.
    static let firstLookByteCounts: [UInt64] = [1 << 20, 4 << 20, largestReadByteCount]
    private static let newline = UInt8(ascii: "\n")

    private struct FollowedFile {
        /// Tells a file that replaced the one read so far.
        let fileNumber: UInt64
        var readOffset: UInt64 = 0
        /// The start of a line Codex was still writing at `readOffset`; the next read completes it.
        var unfinishedLine = Data()
        var turnState: CodexTurnState?
    }

    private let lock = NSLock()
    private var followedFilesByPath: [String: FollowedFile] = [:]

    /// Nil when the file cannot be read, or when its current turn started further back than the first look reads.
    func turnState(ofRolloutFile file: URL) -> CodexTurnState? {
        lock.withLock {
            let path = file.path
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                  let size = (attributes[.size] as? NSNumber)?.uint64Value,
                  let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
                  let handle = try? FileHandle(forReadingFrom: file) else {
                followedFilesByPath[path] = nil
                return nil
            }
            defer { try? handle.close() }
            var followedFile: FollowedFile
            if let known = followedFilesByPath[path], known.fileNumber == fileNumber, known.readOffset <= size,
               size - known.readOffset <= Self.largestReadByteCount {
                followedFile = known
                Self.readAppendedLines(from: handle, upTo: size, into: &followedFile)
            } else {
                followedFile = Self.firstLook(at: handle, size: size, fileNumber: fileNumber)
            }
            followedFilesByPath[path] = followedFile
            return followedFile.turnState
        }
    }

    /// Forgets every file but these, such as those of CLIs that ended.
    func stopFollowingFiles(otherThan paths: Set<String>) {
        lock.withLock { followedFilesByPath = followedFilesByPath.filter { paths.contains($0.key) } }
    }

    private static func firstLook(at handle: FileHandle, size: UInt64, fileNumber: UInt64) -> FollowedFile {
        var followedFile = FollowedFile(fileNumber: fileNumber)
        for byteCount in firstLookByteCounts {
            let start = size > byteCount ? size - byteCount : 0
            guard (try? handle.seek(toOffset: start)) != nil,
                  var text = size > start ? try? handle.read(upToCount: Int(size - start)) : Data() else { break }
            followedFile.readOffset = start + UInt64(text.count)
            // Reading from the middle of the file cuts its first line.
            if start > 0 { text = text.firstIndex(of: newline).map { Data(text[($0 + 1)...]) } ?? Data() }
            let (wholeLines, unfinishedLine) = splitAfterLastNewline(text)
            followedFile.unfinishedLine = unfinishedLine
            // With the whole file read, no turn event means no turn has started.
            followedFile.turnState = CodexTurnState.afterLastTurnEvent(in: wholeLines) ?? (start == 0 ? .betweenTurns : nil)
            if followedFile.turnState != nil { break }
        }
        return followedFile
    }

    private static func readAppendedLines(from handle: FileHandle, upTo size: UInt64, into followedFile: inout FollowedFile) {
        guard size > followedFile.readOffset,
              (try? handle.seek(toOffset: followedFile.readOffset)) != nil,
              let appended = try? handle.read(upToCount: Int(size - followedFile.readOffset)) else { return }
        followedFile.readOffset += UInt64(appended.count)
        let (wholeLines, unfinishedLine) = splitAfterLastNewline(followedFile.unfinishedLine + appended)
        // A line this long is no turn event. Dropping it leaves the rest of it to be read as a line of its own,
        // which no marker matches.
        followedFile.unfinishedLine = UInt64(unfinishedLine.count) > largestReadByteCount ? Data() : unfinishedLine
        if let turnState = CodexTurnState.afterLastTurnEvent(in: wholeLines) { followedFile.turnState = turnState }
    }

    /// The whole lines of `text`, and what follows its last newline.
    private static func splitAfterLastNewline(_ text: Data) -> (wholeLines: Data, rest: Data) {
        guard let lastNewline = text.lastIndex(of: newline) else { return (Data(), text) }
        return (Data(text[...lastNewline]), Data(text[(lastNewline + 1)...]))
    }
}
