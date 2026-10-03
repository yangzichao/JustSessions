import Foundation
import Testing
@testable import JustSessions

struct TranscriptIncrementalIndexTests {
    @Test(arguments: ["", "first\n", "first\npartial", "你好\r\n\n"])
    func appendsOnlyNewBytesAndPreservesPartialRecords(initial: String) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data(initial.utf8).write(to: file)
        let original = try TranscriptFileIndex.read(file, chunkSize: 3)
        let unchanged = try TranscriptFileIndex.read(file, updating: original)
        #expect(unchanged.scannedByteCount == 0)
        let appended = Data(" completed\nsecond\nlast".utf8)
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: appended)
        try handle.close()
        let updated = try TranscriptFileIndex.read(file, chunkSize: 3, updating: unchanged)
        let rebuilt = try TranscriptFileIndex.read(file)
        #expect(updated.lineStarts == rebuilt.lineStarts)
        #expect(updated.scannedByteCount == appended.count)
    }

    @Test func linesAppendedDuringTheScanAreIndexedByTheNextRefresh() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data(String(repeating: "{\"type\":\"event\"}\n", count: 60_000).utf8).write(to: file)
        let appender = try ContinuousLogAppender(file: file)
        appender.start()
        // Small chunks stretch the scan over many reads, so the appender writes between its first and last.
        let scannedWhileAppending = try TranscriptFileIndex.read(file, chunkSize: 4096)
        appender.stop()
        #expect(appender.appendedLineCount > 1)
        let refreshed = try TranscriptFileIndex.read(file, updating: scannedWhileAppending)
        let rebuilt = try TranscriptFileIndex.read(file)
        #expect(refreshed.lineStarts == rebuilt.lineStarts)
        #expect(refreshed.scannedByteCount < rebuilt.scannedByteCount)
    }

    @Test func replacementSameSizeAndDateDoesNotReuseOldOffsets() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try Data("a\nbc".utf8).write(to: file, options: .atomic)
        let original = try TranscriptFileIndex.read(file)
        let date = try #require(FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        try Data("ab\nc".utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        let updated = try TranscriptFileIndex.read(file, updating: original)
        #expect(updated.lineStarts == [0, 3])
        #expect(updated.scannedByteCount == 4)
    }

    @Test func growingRewriteAndTruncationRebuildOffsets() throws {
        let fixture = try TranscriptPagingFixture(count: 0)
        defer { fixture.remove() }
        try Data("a\nbc".utf8).write(to: fixture.file)
        let original = try TranscriptFileIndex.read(fixture.file)
        try Data("abc\ndefgh\n".utf8).write(to: fixture.file)
        let grown = try TranscriptFileIndex.read(fixture.file, updating: original)
        #expect(grown.lineStarts == [0, 4])
        #expect(grown.scannedByteCount == 10)
        try Data("x".utf8).write(to: fixture.file)
        let truncated = try TranscriptFileIndex.read(fixture.file, updating: grown)
        #expect(truncated.lineStarts == [0])
        #expect(truncated.byteCount == 1)
    }
}
