import Foundation
import Testing
@testable import JustSessions

struct SessionFileSummaryCacheTests {
    /// What a scan does: a fresh URL each time, so no resource values are carried over from an earlier look.
    private func scanned(_ file: URL) -> URL {
        URL(fileURLWithPath: file.path)
    }

    @Test func aFileThatHasNotChangedIsNotReadAgain() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try "first line\n".write(to: file, atomically: true, encoding: .utf8)
        let cache = SessionFileSummaryCache<String>()
        var readCount = 0
        let read: (URL) -> String? = { file in
            readCount += 1
            return try? String(contentsOf: file, encoding: .utf8)
        }

        #expect(cache.summary(of: scanned(file), read: read) == "first line\n")
        #expect(cache.summary(of: scanned(file), read: read) == "first line\n")
        #expect(readCount == 1)
    }

    @Test func aFileWrittenToSinceIsReadAgain() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try "first line\n".write(to: file, atomically: true, encoding: .utf8)
        let cache = SessionFileSummaryCache<String>()
        let read: (URL) -> String? = { try? String(contentsOf: $0, encoding: .utf8) }
        _ = cache.summary(of: scanned(file), read: read)

        try "first line\nsecond line\n".write(to: file, atomically: true, encoding: .utf8)

        #expect(cache.summary(of: scanned(file), read: read) == "first line\nsecond line\n")
    }

    @Test func aFileThatHeldNothingIsNotReadAgainUntilItChanges() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try "{}\n".write(to: file, atomically: true, encoding: .utf8)
        let cache = SessionFileSummaryCache<String>()
        var readCount = 0
        let read: (URL) -> String? = { _ in
            readCount += 1
            return nil
        }

        #expect(cache.summary(of: scanned(file), read: read) == nil)
        #expect(cache.summary(of: scanned(file), read: read) == nil)
        #expect(readCount == 1)
    }

    @Test func aFileNoLongerFoundIsForgotten() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let kept = directory.appendingPathComponent("kept.jsonl")
        let deleted = directory.appendingPathComponent("deleted.jsonl")
        try "kept\n".write(to: kept, atomically: true, encoding: .utf8)
        try "deleted\n".write(to: deleted, atomically: true, encoding: .utf8)
        let cache = SessionFileSummaryCache<String>()
        var readPaths: [String] = []
        let read: (URL) -> String? = { file in
            readPaths.append(file.lastPathComponent)
            return file.lastPathComponent
        }
        _ = cache.summary(of: scanned(kept), read: read)
        _ = cache.summary(of: scanned(deleted), read: read)

        cache.forgetFiles(in: directory, except: [kept])
        _ = cache.summary(of: scanned(kept), read: read)
        _ = cache.summary(of: scanned(deleted), read: read)

        #expect(readPaths == ["kept.jsonl", "deleted.jsonl", "deleted.jsonl"])
    }
}
