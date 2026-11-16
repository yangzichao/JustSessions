import Foundation
import Testing
@testable import JustSessions

struct SessionMessageTextCacheTests {
    private let text = SessionMessageText(entries: [.init(id: 4, segments: ["Saved text"])])

    @Test func replacingASameSizeFileWithTheSameDatesInvalidatesItsSavedText() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let conversation = try conversation(in: directory, contents: "old message\n")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: conversation.sourceFile.path)
        let before = SessionMessageTextFingerprint(conversation)
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        cache.save(text, for: conversation.id, fingerprint: before)
        try Data("new message\n".utf8).write(to: conversation.sourceFile, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: conversation.sourceFile.path)
        let after = SessionMessageTextFingerprint(conversation)
        #expect(after.byteCount == before.byteCount)
        #expect(after.modifiedAt == before.modifiedAt)
        #expect(after.inode != before.inode)
        #expect(cache.text(for: conversation.id, fingerprint: after) == nil)
    }

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

    private func resumeState(committedEntryCount: Int = 1, digestByteCount: Int = 4) -> SessionMessageTextResumeState {
        SessionMessageTextResumeState(
            device: 1, inode: 2, byteCount: 9, digest: Data(count: digestByteCount), finalPageRecord: 1, finalPageByteOffset: 9,
            committedEntryCount: committedEntryCount,
            pageLimits: SessionMessageTextResumeState.pageLimits(of: SessionMessageTextReader.codexWholeSessionLimits)
        )
    }

    private func savedFile(in cacheDirectory: URL) throws -> URL {
        try #require(try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil).first)
    }

    @Test func aChangedSessionsTextAndResumeStateAreReadTogether() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        let conversation = try conversation(in: directory)
        cache.save(text, resumeState: resumeState(), for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation))

        try "one line\nand another\n".write(to: conversation.sourceFile, atomically: false, encoding: .utf8)

        guard case .changed(let saved?) = cache.lookup(for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation)) else {
            Issue.record("The saved text and resume state should be offered to resume from")
            return
        }
        #expect(saved.text == text)
        #expect(saved.state == resumeState())
    }

    @Test func anInconsistentResumeStateIsNotResumedFrom() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        for state in [resumeState(committedEntryCount: 2), resumeState(digestByteCount: 32)] {
            let conversation = try conversation(in: directory)
            cache.save(text, resumeState: state, for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation))

            try "one line\nand another\n".write(to: conversation.sourceFile, atomically: false, encoding: .utf8)

            guard case .changed(nil) = cache.lookup(for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation)) else {
                Issue.record("An inconsistent state should read as changed without text to resume from")
                continue
            }
        }
    }

    @Test func textSavedByTheFirstFormatReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)
        cache.save(text, for: conversation.id, fingerprint: fingerprint)
        let encoder = JSONEncoder()
        let firstFormat = try JSONSerialization.data(withJSONObject: [
            "version": 1,
            "conversationID": conversation.id,
            "fingerprint": try JSONSerialization.jsonObject(with: encoder.encode(fingerprint)),
            "text": try JSONSerialization.jsonObject(with: encoder.encode(text)),
        ])

        try firstFormat.write(to: try savedFile(in: cacheDirectory))

        guard case .missing = cache.lookup(for: conversation.id, fingerprint: fingerprint) else {
            Issue.record("Text in the first format should read as missing")
            return
        }
    }

    @Test func aHeaderOfAnotherVersionReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)
        cache.save(text, for: conversation.id, fingerprint: fingerprint)
        let file = try savedFile(in: cacheDirectory)
        let current = Data("\"version\":\(SessionMessageTextCache.formatVersion)".utf8)
        var saved = try Data(contentsOf: file)
        let version = try #require(saved.range(of: current))

        saved.replaceSubrange(version, with: Data("\"version\":9".utf8))
        try saved.write(to: file)

        guard case .missing = cache.lookup(for: conversation.id, fingerprint: fingerprint) else {
            Issue.record("Text of another version should read as missing")
            return
        }
    }

    @Test func anotherSessionsTextReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let first = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(first)
        cache.save(text, resumeState: resumeState(), for: first.id, fingerprint: fingerprint)
        let firstFile = try savedFile(in: cacheDirectory)
        let second = Conversation.fixture(provider: .codex, sessionID: "another session", sourceFile: first.sourceFile)

        cache.save(text, for: second.id, fingerprint: fingerprint)
        let secondFile = try #require(try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent != firstFile.lastPathComponent })

        try Data(contentsOf: firstFile).write(to: secondFile)

        guard case .missing = cache.lookup(for: second.id, fingerprint: fingerprint) else {
            Issue.record("Another session's text should read as missing")
            return
        }
    }

    @Test func cutShortSavedTextReadsAsMissing() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheDirectory = directory.appendingPathComponent("Cache")
        let cache = SessionMessageTextCache(directory: cacheDirectory)
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)
        cache.save(text, resumeState: resumeState(), for: conversation.id, fingerprint: fingerprint)
        let file = try savedFile(in: cacheDirectory)
        let saved = try Data(contentsOf: file)

        try saved.dropLast(3).write(to: file)
        #expect(cache.text(for: conversation.id, fingerprint: fingerprint) == nil)

        try "one line\nand another\n".write(to: conversation.sourceFile, atomically: false, encoding: .utf8)
        guard case .changed(nil) = cache.lookup(for: conversation.id, fingerprint: SessionMessageTextFingerprint(conversation)) else {
            Issue.record("Cut-short text should not be resumed from")
            return
        }
    }

    @Test func simultaneousSavesLeaveOneWholeSave() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
        let conversation = try conversation(in: directory)
        let fingerprint = SessionMessageTextFingerprint(conversation)
        let choices = (0..<12).map { SessionMessageText(entries: [.init(id: $0, segments: ["Choice \($0)"])]) }

        await withTaskGroup(of: Void.self) { group in
            for text in choices {
                group.addTask { cache.save(text, for: conversation.id, fingerprint: fingerprint) }
            }
        }

        #expect(choices.contains(try #require(cache.text(for: conversation.id, fingerprint: fingerprint))))
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
