import Foundation
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct SessionMessageIndexerTests {
    private let user = UUID()

    private func codexSession(_ messages: [String], in directory: URL, sessionID: String = UUID().uuidString.lowercased(),
                              updatedAt: Date = .now) throws -> Conversation {
        let file = directory.appendingPathComponent("\(sessionID).jsonl")
        try SampleTranscriptLines.fileContents(messages.map { codexLine($0) }).write(to: file)
        return .fixture(provider: .codex, sessionID: sessionID, updatedAt: updatedAt, sourceFile: file)
    }

    private func codexLine(_ text: String) -> String {
        #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(text)"}]}}"#
    }

    private func makeIndexer(cacheIn directory: URL) -> SessionMessageIndexer {
        let indexer = SessionMessageIndexer(index: SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))))
        indexer.publishInterval = .zero
        return indexer
    }

    private func matches(_ text: String, in indexer: SessionMessageIndexer) async throws -> [String: SessionMessageMatch] {
        try await indexer.index.matches(for: try #require(SessionMessageQuery(text)))
    }

    /// Waits for the update started after `revision` to finish.
    private func waitForUpdate(of indexer: SessionMessageIndexer, after revision: Int) async throws {
        try await expectEventually { indexer.revision > revision && indexer.progress == nil }
    }

    @Test func findsTheSessionsWhoseMessagesHoldTheText() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        let matching = try codexSession(["Opening the file", "The cache key is stale"], in: directory)
        let other = try codexSession(["Nothing to see"], in: directory)

        indexer.beginUse(by: user)
        indexer.update(with: [matching, other])
        try await waitForUpdate(of: indexer, after: 0)

        let found = try await matches("CACHE KEY", in: indexer)
        #expect(Set(found.keys) == [matching.id])
        #expect(found[matching.id]?.entryID == TranscriptPageIdentity.entryID(record: 1, part: 0))
        #expect(found[matching.id]?.snippet.matchedText == "cache key")
    }

    @Test func aChangedSessionIsReadAgain() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        let session = try codexSession(["First message"], in: directory)
        indexer.beginUse(by: user)
        indexer.update(with: [session])
        try await waitForUpdate(of: indexer, after: 0)
        #expect(try await matches("later message", in: indexer).isEmpty)

        let grown = try codexSession(["First message", "A later message"], in: directory, sessionID: session.sessionID,
                                     updatedAt: session.updatedAt.addingTimeInterval(5))
        let revision = indexer.revision
        indexer.update(with: [grown])
        try await waitForUpdate(of: indexer, after: revision)

        #expect(try await matches("later message", in: indexer).keys.contains(grown.id))
    }

    @Test func anUnchangedSessionIsTakenFromTheCacheWithoutReadingIt() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["Remember this message"], in: directory)
        let firstIndexer = makeIndexer(cacheIn: directory)
        firstIndexer.beginUse(by: user)
        firstIndexer.update(with: [session])
        try await waitForUpdate(of: firstIndexer, after: 0)

        // A session file nobody can read still has its size and modification date.
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: session.sourceFile.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: session.sourceFile.path) }
        let relaunchedIndexer = makeIndexer(cacheIn: directory)
        relaunchedIndexer.beginUse(by: user)
        relaunchedIndexer.update(with: [session])
        try await waitForUpdate(of: relaunchedIndexer, after: 0)

        #expect(try await matches("remember this", in: relaunchedIndexer).keys.contains(session.id))
    }

    @Test func sessionsNoLongerListedAreNotSearched() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        let kept = try codexSession(["Shared words"], in: directory)
        let removed = try codexSession(["Shared words"], in: directory)
        indexer.beginUse(by: user)
        indexer.update(with: [kept, removed])
        try await waitForUpdate(of: indexer, after: 0)
        #expect(try await matches("shared", in: indexer).count == 2)

        let revision = indexer.revision
        indexer.update(with: [kept])
        try await waitForUpdate(of: indexer, after: revision)

        #expect(Set(try await matches("shared", in: indexer).keys) == [kept.id])
    }

    @Test func theTextLeavesMemoryAfterTheLastSearchEnds() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        indexer.unloadDelay = .milliseconds(50)
        let session = try codexSession(["Some words"], in: directory)
        let otherWindow = UUID()
        indexer.beginUse(by: user)
        indexer.beginUse(by: otherWindow)
        indexer.update(with: [session])
        try await waitForUpdate(of: indexer, after: 0)

        indexer.endUse(by: user)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await matches("some words", in: indexer).count == 1)

        indexer.endUse(by: otherWindow)
        let deadline = ContinuousClock.now + .seconds(10)
        while try await !matches("some words", in: indexer).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(try await matches("some words", in: indexer).isEmpty)
    }

    @Test func searchingAgainBeforeTheDelayKeepsTheTextAndReadsNothing() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        indexer.unloadDelay = .milliseconds(100)
        let session = try codexSession(["Some words"], in: directory)
        indexer.beginUse(by: user)
        indexer.update(with: [session])
        try await waitForUpdate(of: indexer, after: 0)

        indexer.endUse(by: user)
        indexer.beginUse(by: user)
        let revision = indexer.revision
        indexer.update(with: [session])
        try await waitForUpdate(of: indexer, after: revision)
        try await Task.sleep(for: .milliseconds(300))

        #expect(try await matches("some words", in: indexer).count == 1)
    }
}
