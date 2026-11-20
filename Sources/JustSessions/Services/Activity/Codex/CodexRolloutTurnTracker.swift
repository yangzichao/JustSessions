import Foundation
import os

final class CodexRolloutTurnTracker: Sendable {
    static let largestReadByteCount: UInt64 = 16 << 20
    static let firstLookByteCounts: [UInt64] = [1 << 20, 4 << 20, largestReadByteCount]
    private static let newline = UInt8(ascii: "\n")

    private struct FollowedFile: Sendable {
        let fileNumber: UInt64
        var readOffset: UInt64 = 0
        var unfinishedLine = Data()
        var turnState: CodexTurnState?
    }

    private let followedFilesByPath = OSAllocatedUnfairLock<[String: FollowedFile]>(initialState: [:])

    func turnState(ofRolloutFile file: URL) -> CodexTurnState? {
        followedFilesByPath.withLock { followedFilesByPath in
            let path = file.path
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: path),
                let size = (attributes[.size] as? NSNumber)?.uint64Value,
                let fileNumber = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
                let handle = try? FileHandle(forReadingFrom: file)
            else {
                followedFilesByPath[path] = nil
                return nil
            }
            defer { try? handle.close() }
            var followedFile: FollowedFile
            if let known = followedFilesByPath[path], known.fileNumber == fileNumber, known.readOffset <= size,
                size - known.readOffset <= Self.largestReadByteCount
            {
                followedFile = known
                Self.readAppendedLines(from: handle, upTo: size, into: &followedFile)
            } else {
                followedFile = Self.firstLook(at: handle, size: size, fileNumber: fileNumber)
            }
            followedFilesByPath[path] = followedFile
            return followedFile.turnState
        }
    }

    func stopFollowingFiles(otherThan paths: Set<String>) {
        followedFilesByPath.withLock { followedFilesByPath in
            followedFilesByPath = followedFilesByPath.filter { paths.contains($0.key) }
        }
    }

    private static func firstLook(at handle: FileHandle, size: UInt64, fileNumber: UInt64) -> FollowedFile {
        var followedFile = FollowedFile(fileNumber: fileNumber)
        for byteCount in firstLookByteCounts {
            let start = size > byteCount ? size - byteCount : 0
            guard (try? handle.seek(toOffset: start)) != nil,
                var text = size > start ? try? handle.read(upToCount: Int(size - start)) : Data()
            else { break }
            followedFile.readOffset = start + UInt64(text.count)
            if start > 0 { text = text.firstIndex(of: newline).map { Data(text[($0 + 1)...]) } ?? Data() }
            let (wholeLines, unfinishedLine) = splitAfterLastNewline(text)
            followedFile.unfinishedLine = unfinishedLine
            followedFile.turnState = CodexTurnState.afterLastTurnEvent(in: wholeLines) ?? (start == 0 ? .betweenTurns : nil)
            if followedFile.turnState != nil { break }
        }
        return followedFile
    }

    private static func readAppendedLines(from handle: FileHandle, upTo size: UInt64, into followedFile: inout FollowedFile) {
        guard size > followedFile.readOffset,
            (try? handle.seek(toOffset: followedFile.readOffset)) != nil,
            let appended = try? handle.read(upToCount: Int(size - followedFile.readOffset))
        else { return }
        followedFile.readOffset += UInt64(appended.count)
        let (wholeLines, unfinishedLine) = splitAfterLastNewline(followedFile.unfinishedLine + appended)
        followedFile.unfinishedLine = droppingLineTooLongToBeATurnEvent(unfinishedLine)
        if let turnState = CodexTurnState.afterLastTurnEvent(in: wholeLines) { followedFile.turnState = turnState }
    }

    private static func droppingLineTooLongToBeATurnEvent(_ unfinishedLine: Data) -> Data {
        let isTooLongToBeATurnEvent = UInt64(unfinishedLine.count) > largestReadByteCount
        return isTooLongToBeATurnEvent ? Data() : unfinishedLine
    }

    private static func splitAfterLastNewline(_ text: Data) -> (wholeLines: Data, rest: Data) {
        guard let lastNewline = text.lastIndex(of: newline) else { return (Data(), text) }
        return (Data(text[...lastNewline]), Data(text[(lastNewline + 1)...]))
    }
}
