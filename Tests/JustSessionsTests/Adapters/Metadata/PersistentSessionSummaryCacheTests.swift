import Foundation
import Testing
@testable import JustSessions

struct PersistentSessionSummaryCacheTests {
    @Test func newCacheInstanceReusesValidatedSnapshotAndInvalidatesReplacement() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        let snapshot = directory.appendingPathComponent("cache/snapshot.json")
        try Data("old".utf8).write(to: file, options: .atomic)
        let first = SessionFileSummaryCache<String>(persistenceFile: snapshot, persistsTemporaryFiles: true)
        #expect(first.summary(of: file) { _ in "old" } == "old")
        first.forgetFiles(in: directory, except: [file])
        let second = SessionFileSummaryCache<String>(persistenceFile: snapshot, persistsTemporaryFiles: true)
        #expect(second.summary(of: URL(fileURLWithPath: file.path)) { _ in Issue.record("Unchanged files should not be parsed again"); return nil } == "old")
        let date = try #require(FileManager.default.attributesOfItem(atPath: file.path)[.modificationDate] as? Date)
        try Data("new".utf8).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        #expect(second.summary(of: URL(fileURLWithPath: file.path)) { _ in "new" } == "new")
        second.forgetFiles(in: directory, except: [])
        let third = SessionFileSummaryCache<String>(persistenceFile: snapshot, persistsTemporaryFiles: true)
        #expect(third.summary(of: URL(fileURLWithPath: file.path)) { _ in "reread" } == "reread")
    }

    @Test(arguments: ["invalid", "{\"version\":999,\"entries\":{}}"])
    func corruptAndIncompatibleCachesFallBackToSource(contents: String) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session")
        let snapshot = directory.appendingPathComponent("snapshot")
        try Data("source".utf8).write(to: file)
        try Data(contents.utf8).write(to: snapshot)
        let cache = SessionFileSummaryCache<String>(persistenceFile: snapshot)
        #expect(cache.summary(of: file) { _ in "source" } == "source")
    }
}
