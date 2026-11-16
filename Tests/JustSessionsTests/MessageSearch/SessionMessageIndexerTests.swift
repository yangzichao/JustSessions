import Foundation
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct SessionMessageIndexerTests {
    private let user = UUID()

    @Test func aFailedReadRetriesWithoutChangingTheQueryOrListedSessions() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["Recovered after a transient failure"], in: directory)
        let reads = AsyncCounter()
        let retry = MessageSearchRetryGate()
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { conversation, fingerprint, cache in
            await reads.increment()
            if await reads.value == 1 { return nil }
            return await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }
        indexer.waitBeforeRetry = { await retry.wait($0) }
        defer { indexer.endUse(by: user) }
        indexer.beginUse(by: user)
        await indexer.update(with: [session], for: user)
        try await expectEventually { retry.waitCount == 1 }
        #expect(await index.sessionCount() == 0)
        let revision = indexer.revision
        // Progress and query reruns cannot bypass the pending backoff or create a retry loop.
        for _ in 0..<100 { await indexer.update(with: [session], for: user) }
        #expect(await reads.value == 1)
        retry.release()
        try await waitForUpdate(of: indexer, after: revision)
        #expect(await reads.value == 2)
        #expect(try await matches("recovered", in: indexer).keys.contains(session.id))
    }

    @Test func closingTheLastSearchCancelsItsPendingRetry() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["Unreadable"], in: directory)
        let reads = AsyncCounter()
        let retry = MessageSearchRetryGate()
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { _, _, _ in
            await reads.increment()
            return nil
        }
        indexer.waitBeforeRetry = { await retry.wait($0) }
        indexer.beginUse(by: user)
        await indexer.update(with: [session], for: user)
        try await expectEventually { retry.waitCount == 1 }
        indexer.endUse(by: user)
        retry.release()
        try await expectEventually { retry.finished }
        #expect(retry.wasCancelled)
        #expect(await reads.value == 1)
        #expect(await index.sessionCount() == 0)
    }

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

    /// Waits for the update started after `revision` to finish. The update publishes on the main actor, which the
    /// suite's window tests keep busy for half a minute or more on shared CI runners as the suite starts.
    private func waitForUpdate(of indexer: SessionMessageIndexer, after revision: Int) async throws {
        try await expectEventually(timeout: .seconds(120)) { indexer.revision > revision && indexer.progress == nil }
    }

    @Test func findsTheSessionsWhoseMessagesHoldTheText() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        let matching = try codexSession(["Opening the file", "The cache key is stale"], in: directory)
        let other = try codexSession(["Nothing to see"], in: directory)

        indexer.beginUse(by: user)
        await indexer.update(with: [matching, other], for: user)
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
        await indexer.update(with: [session], for: user)
        try await waitForUpdate(of: indexer, after: 0)
        #expect(try await matches("later message", in: indexer).isEmpty)

        let grown = try codexSession(["First message", "A later message"], in: directory, sessionID: session.sessionID,
                                     updatedAt: session.updatedAt.addingTimeInterval(5))
        let revision = indexer.revision
        await indexer.update(with: [grown], for: user)
        try await waitForUpdate(of: indexer, after: revision)

        #expect(try await matches("later message", in: indexer).keys.contains(grown.id))
    }

    @Test func aRenamedSourceFileReplacesItsIndexedText() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["Before file rename"], in: directory)
        let indexer = makeIndexer(cacheIn: directory)
        indexer.beginUse(by: user)
        await indexer.update(with: [session], for: user)
        try await waitForUpdate(of: indexer, after: 0)

        let renamedFile = directory.appendingPathComponent("renamed.jsonl")
        try FileManager.default.moveItem(at: session.sourceFile, to: renamedFile)
        try SampleTranscriptLines.fileContents([codexLine("After file rename")]).write(to: renamedFile)
        let renamed = Conversation.fixture(
            provider: .codex,
            sessionID: session.sessionID,
            updatedAt: session.updatedAt.addingTimeInterval(5),
            sourceFile: renamedFile
        )
        let revision = indexer.revision
        await indexer.update(with: [renamed], for: user)
        try await waitForUpdate(of: indexer, after: revision)

        #expect(try await matches("before file rename", in: indexer).isEmpty)
        #expect(Set(try await matches("after file rename", in: indexer).keys) == [renamed.id])
    }

    @Test func aStaleInFlightReadCannotOverwriteAnAppendedSession() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["First message"], in: directory)
        let reader = PausedFirstMessageReader()
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { conversation, fingerprint, cache in
            await reader.read(conversation, fingerprint: fingerprint, cache: cache)
        }
        indexer.beginUse(by: user)
        await indexer.update(with: [session], for: user)
        let pauseDeadline = ContinuousClock.now + .seconds(120)
        while await !reader.hasPausedRead, ContinuousClock.now < pauseDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await reader.hasPausedRead)

        let grown = try codexSession(
            ["First message", "A later generation"], in: directory, sessionID: session.sessionID,
            updatedAt: session.updatedAt.addingTimeInterval(5)
        )
        await indexer.update(with: [grown], for: user)
        await reader.release()
        try await waitForUpdate(of: indexer, after: 0)

        #expect(Set(try await matches("later generation", in: indexer).keys) == [grown.id])
        #expect(await reader.readCount == 2)
    }

    @Test func anUnchangedSessionIsTakenFromTheCacheWithoutReadingIt() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["Remember this message"], in: directory)
        let firstIndexer = makeIndexer(cacheIn: directory)
        firstIndexer.beginUse(by: user)
        await firstIndexer.update(with: [session], for: user)
        try await waitForUpdate(of: firstIndexer, after: 0)

        // A session file nobody can read still has its size and modification date.
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: session.sourceFile.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: session.sourceFile.path) }
        let relaunchedIndexer = makeIndexer(cacheIn: directory)
        relaunchedIndexer.beginUse(by: user)
        await relaunchedIndexer.update(with: [session], for: user)
        try await waitForUpdate(of: relaunchedIndexer, after: 0)

        #expect(try await matches("remember this", in: relaunchedIndexer).keys.contains(session.id))
    }

    @Test func simultaneousUsersShareOneReadOfTheSameGeneration() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = try codexSession(["One shared copy"], in: directory)
        let reads = AsyncCounter()
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { conversation, fingerprint, cache in
            await reads.increment()
            try? await Task.sleep(for: .milliseconds(50))
            return await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }
        let otherWindow = UUID()
        indexer.beginUse(by: user)
        indexer.beginUse(by: otherWindow)

        await indexer.update(with: [session], for: user)
        await indexer.update(with: [session], for: otherWindow)
        try await waitForUpdate(of: indexer, after: 0)

        #expect(await reads.value == 1)
        #expect(await index.sessionCount() == 1)
        #expect(Set(try await matches("shared copy", in: indexer).keys) == [session.id])
    }

    @Test func oneUsersSubsetDoesNotPruneAnotherUsersIndex() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try codexSession(["First window only"], in: directory)
        let second = try codexSession(["Second window remains"], in: directory)
        let indexer = makeIndexer(cacheIn: directory)
        let otherWindow = UUID()
        indexer.beginUse(by: user)
        indexer.beginUse(by: otherWindow)
        await indexer.update(with: [first], for: user)
        await indexer.update(with: [second], for: otherWindow)
        try await waitForUpdate(of: indexer, after: 0)

        indexer.endUse(by: user)
        let deadline = ContinuousClock.now + .seconds(120)
        while await indexer.index.sessionCount() != 1, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await indexer.index.sessionCount() == 1)

        #expect(try await matches("first window", in: indexer).isEmpty)
        #expect(Set(try await matches("second window", in: indexer).keys) == [second.id])
    }

    @Test func removingAHostInvalidatesOtherUsersStaleListsUntilItIsReadded() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let remote = try codexSession(["Remote mirror text"], in: directory).onHost(.ssh("devbox"))
        let indexer = makeIndexer(cacheIn: directory)
        let otherWindow = UUID()
        indexer.beginUse(by: user)
        indexer.beginUse(by: otherWindow)
        await indexer.update(with: [remote], for: user)
        await indexer.update(with: [remote], for: otherWindow)
        try await waitForUpdate(of: indexer, after: 0)

        indexer.removeHost(.ssh("devbox"))
        let removalDeadline = ContinuousClock.now + .seconds(120)
        while await indexer.index.sessionCount() != 0, ContinuousClock.now < removalDeadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(await indexer.index.sessionCount() == 0)
        await indexer.update(with: [remote], for: otherWindow)
        #expect(try await matches("remote mirror", in: indexer).isEmpty)

        let revision = indexer.revision
        indexer.restoreHost(.ssh("devbox"))
        try await waitForUpdate(of: indexer, after: revision)
        #expect(Set(try await matches("remote mirror", in: indexer).keys) == [remote.id])
    }

    @Test func closingOneUserDuringAnUpdateDoesNotCancelTheOthersRead() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let closing = try codexSession(["Closing window"], in: directory)
        let remaining = try codexSession(["Remaining window"], in: directory)
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { conversation, fingerprint, cache in
            try? await Task.sleep(for: .milliseconds(50))
            return await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }
        let otherWindow = UUID()
        indexer.beginUse(by: user)
        indexer.beginUse(by: otherWindow)
        await indexer.update(with: [closing], for: user)
        await indexer.update(with: [remaining], for: otherWindow)

        indexer.endUse(by: user)
        try await waitForUpdate(of: indexer, after: 0)

        #expect(try await matches("closing window", in: indexer).isEmpty)
        #expect(Set(try await matches("remaining window", in: indexer).keys) == [remaining.id])
    }

    @Test func sessionsNoLongerListedAreNotSearched() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let indexer = makeIndexer(cacheIn: directory)
        let kept = try codexSession(["Shared words"], in: directory)
        let removed = try codexSession(["Shared words"], in: directory)
        indexer.beginUse(by: user)
        await indexer.update(with: [kept, removed], for: user)
        try await waitForUpdate(of: indexer, after: 0)
        #expect(try await matches("shared", in: indexer).count == 2)

        let revision = indexer.revision
        await indexer.update(with: [kept], for: user)
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
        await indexer.update(with: [session], for: user)
        await indexer.update(with: [session], for: otherWindow)
        try await waitForUpdate(of: indexer, after: 0)

        indexer.endUse(by: user)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try await matches("some words", in: indexer).count == 1)

        indexer.endUse(by: otherWindow)
        let deadline = ContinuousClock.now + .seconds(120)
        while try await !matches("some words", in: indexer).isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(try await matches("some words", in: indexer).isEmpty)
    }

    @Test func searchingAgainBeforeTheDelayKeepsTheTextAndReadsNothing() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let reads = AsyncCounter()
        let index = SessionMessageIndex(cache: SessionMessageTextCache(directory: directory.appendingPathComponent("Cache")))
        let indexer = SessionMessageIndexer(index: index) { conversation, fingerprint, cache in
            await reads.increment()
            return await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }
        indexer.unloadDelay = .milliseconds(200)
        let session = try codexSession(["Some words"], in: directory)
        indexer.beginUse(by: user)
        await indexer.update(with: [session], for: user)
        try await waitForUpdate(of: indexer, after: 0)
        #expect(await reads.value == 1)

        indexer.endUse(by: user)
        try await Task.sleep(for: .milliseconds(50))
        #expect(await index.sessionCount() == 1)
        indexer.beginUse(by: user)
        let revision = indexer.revision
        await indexer.update(with: [session], for: user)
        try await waitForUpdate(of: indexer, after: revision)
        try await Task.sleep(for: .milliseconds(300))

        #expect(await reads.value == 1)
        #expect(await index.sessionCount() == 1)
        #expect(try await matches("some words", in: indexer).count == 1)
    }
}

private actor PausedFirstMessageReader {
    private(set) var readCount = 0
    private(set) var hasPausedRead = false
    private var continuation: CheckedContinuation<Void, Never>?

    func read(
        _ conversation: Conversation,
        fingerprint: SessionMessageTextFingerprint,
        cache: SessionMessageTextCache
    ) async -> SearchableSessionText? {
        readCount += 1
        let text = await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        if readCount == 1 {
            hasPausedRead = true
            await withCheckedContinuation { continuation = $0 }
        }
        return text
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

private actor AsyncCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

@MainActor
private final class MessageSearchRetryGate {
    private(set) var waitCount = 0
    private(set) var finished = false
    private(set) var wasCancelled = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait(_ delay: Duration) async {
        waitCount += 1
        await withCheckedContinuation { continuation = $0 }
        wasCancelled = Task.isCancelled
        finished = true
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
