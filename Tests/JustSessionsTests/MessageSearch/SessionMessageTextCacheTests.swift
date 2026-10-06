import Foundation
import Testing
@testable import JustSessions

struct SessionMessageTextCacheTests {
    private let text = SessionMessageText(entries: [.init(id: 4, segments: ["Saved text"])])

    private func conversation(in directory: URL, provider: ConversationProvider = .codex, contents: String = "one line\n") throws -> Conversation {
        let file = directory.appendingPathComponent("\(UUID().uuidString).jsonl")
        try contents.write(to: file, atomically: true, encoding: .utf8)
        return .fixture(provider: provider, sessionID: "session:with@odd chars/\(UUID().uuidString)", sourceFile: file)
    }

    @Test func savedTextReadsBackWhileTheSessionIsUnchanged() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)

        #expect(cache.text(for: conversation.id, fingerprint: fingerprint) == nil)
        cache.save(text, for: conversation.id, fingerprint: fingerprint)

        #expect(cache.text(for: conversation.id, fingerprint: fingerprint) == text)
        #expect(cache.text(for: "another session", fingerprint: fingerprint) == nil)
    }

    @Test func aChangedSessionReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        let conversation = try conversation(in: directory)
        cache.save(text, for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation))

        try "one line\nand another\n".write(to: conversation.sourceFile, atomically: true, encoding: .utf8)

        #expect(cache.text(for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation)) == nil)
    }

    @Test func anUnreadableCacheFileReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)
        cache.save(text, for: conversation.id, fingerprint: fingerprint)
        let savedFile = try #require(try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil).first)

        try Data("{ not json".utf8).write(to: savedFile)

        #expect(cache.text(for: conversation.id, fingerprint: fingerprint) == nil)
    }

    @Test func openCodeSessionsGoByTheirOwnLastActivityAsTheirDatabaseHoldsEveryOne() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try conversation(in: directory, provider: .opencode)
        let before = SessionMessageTextFingerprint(session)

        try "another session's messages\n".write(to: session.sourceFile, atomically: true, encoding: .utf8)

        #expect(SessionMessageTextFingerprint(session) == before)
        let laterSession = Conversation.fixture(
            provider: .opencode, sessionID: session.sessionID, updatedAt: session.updatedAt.addingTimeInterval(1), sourceFile: session.sourceFile
        )
        #expect(SessionMessageTextFingerprint(laterSession) != before)
    }

    @Test func textOfSessionsNoLongerListedIsDeletedOnceUnusedForTheRetention() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let listed = try conversation(in: directory)
        let recentlyUnlisted = try conversation(in: directory)
        let longUnlisted = try conversation(in: directory)
        for conversation in [listed, recentlyUnlisted, longUnlisted] {
            cache.save(text, for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation))
        }
        let longAgo = Date.now.addingTimeInterval(-SessionMessageTextCache.unlistedRetention - 60)
        let savedFiles = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for file in savedFiles {
            try FileManager.default.setAttributes([.modificationDate: longAgo], ofItemAtPath: file.path)
        }
        cache.save(text, for: recentlyUnlisted.id, fingerprint: SessionMessageTextFingerprint(recentlyUnlisted))

        cache.removeText(ofSessionsOtherThan: [listed.id])

        #expect(cache.text(for: listed.id, fingerprint: SessionMessageTextFingerprint(listed)) == text)
        #expect(cache.text(for: recentlyUnlisted.id, fingerprint: SessionMessageTextFingerprint(recentlyUnlisted)) == text)
        #expect(cache.text(for: longUnlisted.id, fingerprint: SessionMessageTextFingerprint(longUnlisted)) == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: cacheDirectory.path).count == 2)
    }
}
