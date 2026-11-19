import Foundation
import Testing

@testable import JustSessions

/// `SessionMessageIndex.searchableText`: when it keeps a resume state with a session's saved text, and that what it
/// saves always matches a clean read.
@Suite(.serialized)
struct SessionMessageIndexSearchableTextTests {
    private struct Session {
        let directory: URL
        let cache: SessionMessageTextCache
        let conversation: Conversation

        init(provider: ConversationProvider = .codex, host: SessionHost = .thisMac, lines: [String]) throws {
            directory = try makeTemporaryDirectory()
            cache = SessionMessageTextCache(directory: directory.appendingPathComponent("Cache"))
            let file = directory.appendingPathComponent("session.jsonl")
            try SampleTranscriptLines.fileContents(lines).write(to: file)
            conversation = .fixture(provider: provider, sourceFile: file, host: host)
        }

        var fingerprint: SessionMessageTextFingerprint { SessionMessageTextFingerprint(conversation) }

        func append(_ line: String) throws {
            let handle = try FileHandle(forWritingTo: conversation.sourceFile)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: SampleTranscriptLines.fileContents([line]))
        }

        func searchableText() async -> SearchableSessionText? {
            await SessionMessageIndex.searchableText(of: conversation, fingerprint: fingerprint, cache: cache)
        }

        /// The resume state saved with the session's text, looked up as after a change.
        func savedResumeState() throws -> SessionMessageTextResumeState? {
            let changed = SessionMessageTextFingerprint(
                .fixture(provider: conversation.provider, updatedAt: .distantPast, sourceFile: conversation.sourceFile)
            )
            guard case .changed(let saved) = cache.lookup(for: conversation.id, fingerprint: changed) else {
                Issue.record("Nothing saved for the session")
                return nil
            }
            return saved?.state
        }

        func savedFile() throws -> Data? {
            let files = (try? FileManager.default.contentsOfDirectory(at: cache.directory, includingPropertiesForKeys: nil)) ?? []
            return try files.first.map { try Data(contentsOf: $0) }
        }

        func remove() { try? FileManager.default.removeItem(at: directory) }
    }

    private static let assistant = CodexSessionTextResumerTests.assistant

    private func expectCleanReadText(_ text: SearchableSessionText?, of session: Session) async throws {
        let clean = try await SessionMessageTextReader.read(session.conversation)
        #expect(text?.text == clean)
        #expect(session.cache.text(for: session.conversation.id, fingerprint: session.fingerprint) == clean)
    }

    @Test func aFirstReadKeepsNoResumeStateButAReadAfterAChangeDoes() async throws {
        let session = try Session(lines: [Self.assistant("First")])
        defer { session.remove() }

        try await expectCleanReadText(await session.searchableText(), of: session)
        #expect(try session.savedResumeState() == nil)

        try session.append(Self.assistant("Second"))
        try await expectCleanReadText(await session.searchableText(), of: session)
        let state = try #require(try session.savedResumeState())

        try session.append(Self.assistant("Third"))
        try await expectCleanReadText(await session.searchableText(), of: session)
        #expect(try #require(try session.savedResumeState()).byteCount > state.byteCount)
    }

    @Test func anotherProvidersSessionNeverKeepsAResumeState() async throws {
        let session = try Session(provider: .claude, lines: SampleTranscriptLines.claude)
        defer { session.remove() }
        let line = #"{"type":"user","timestamp":"2026-09-24T10:01:00.000Z","message":{"role":"user","content":"Again"}}"#

        for _ in 0..<3 {
            try await expectCleanReadText(await session.searchableText(), of: session)
            #expect(try session.savedResumeState() == nil)
            try session.append(line)
        }
    }

    /// A mirrored session's file is replaced at every copy, so a resume state would only cost a hash at each change.
    @Test func aCodexSessionOnAnSSHHostNeverKeepsAResumeState() async throws {
        let session = try Session(host: .ssh("devbox"), lines: [Self.assistant("First")])
        defer { session.remove() }

        for number in 0..<3 {
            try await expectCleanReadText(await session.searchableText(), of: session)
            #expect(try session.savedResumeState() == nil)
            try session.append(Self.assistant("Appended \(number)"))
        }
    }

    @Test func twoConsumersReadingTheSameAppendBothSaveCleanText() async throws {
        let session = try Session(lines: (0..<20).map { Self.assistant("Message \($0)") })
        defer { session.remove() }
        _ = await session.searchableText()
        try session.append(Self.assistant("Changed"))
        _ = await session.searchableText()

        for number in 0..<3 {
            try session.append(Self.assistant("Appended \(number)"))
            async let first = session.searchableText()
            async let second = session.searchableText()
            let (firstText, secondText) = await (first, second)
            let clean = try await SessionMessageTextReader.read(session.conversation)
            #expect(firstText?.text == clean)
            #expect(secondText?.text == clean)
            #expect(session.cache.text(for: session.conversation.id, fingerprint: session.fingerprint) == clean)
            #expect(try session.savedResumeState() != nil)
        }
    }

    @Test func aCancelledFirstReadSavesNothing() async throws {
        let session = try Session(lines: [Self.assistant("First")])
        defer { session.remove() }

        let task = Task {
            try? await Task.sleep(for: .seconds(60))
            return await session.searchableText()
        }
        task.cancel()

        #expect(await task.value == nil)
        #expect(try session.savedFile() == nil)
    }

    @Test func aCancelledReadOfAChangedSessionKeepsWhatWasSaved() async throws {
        let session = try Session(lines: (0..<20).map { Self.assistant("Message \($0)") })
        defer { session.remove() }
        _ = await session.searchableText()
        try session.append(Self.assistant("Changed"))
        _ = await session.searchableText()
        let saved = try #require(try session.savedFile())
        try session.append(Self.assistant("Appended"))

        let task = Task {
            try? await Task.sleep(for: .seconds(60))
            return await session.searchableText()
        }
        task.cancel()

        #expect(await task.value == nil)
        #expect(try session.savedFile() == saved)
    }
}
