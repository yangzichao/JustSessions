import Foundation
import Testing

@testable import JustSessions

/// A Codex session read after an append resumes from its saved final page, and must give exactly the text a clean
/// full read gives: the same entries, IDs, and segments.
@Suite(.serialized)
struct CodexSessionTextResumerTests {
    /// Small pages, so a few records make several pages and the final page moves as records are appended.
    static let smallPages = TranscriptPageLimits(targetEntryCount: 3, maximumRecordCount: 6, targetByteCount: 1 << 20)

    static func assistant(_ text: String) -> String {
        #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(text)"}]}}"#
    }

    static func user(_ text: String) -> String {
        #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"\#(text)"}]}}"#
    }

    static func toolCall(_ input: String) -> String {
        #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"custom_tool_call","name":"apply_patch","input":"\#(input)"}}"#
    }

    static func event(_ padding: Int = 40) -> String {
        #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count","padding":"\#(String(repeating: "x", count: padding))"}}"#
    }

    private struct Session {
        let directory: URL
        let file: URL
        let conversation: Conversation

        init(_ lines: [String]) throws {
            directory = try makeTemporaryDirectory()
            file = directory.appendingPathComponent("rollout.jsonl")
            try SampleTranscriptLines.fileContents(lines).write(to: file)
            conversation = .fixture(provider: .codex, sourceFile: file)
        }

        func append(_ data: Data) throws {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        }

        func append(lines: [String]) throws {
            try append(SampleTranscriptLines.fileContents(lines))
        }

        /// Rewrites the file in place, keeping its inode.
        func rewrite(_ data: Data) throws {
            let handle = try FileHandle(forUpdating: file)
            defer { try? handle.close() }
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: data)
        }

        func remove() { try? FileManager.default.removeItem(at: directory) }
    }

    /// A full read that keeps a resume state, as for a session seen changing.
    private func savedRead(of session: Session, limits: TranscriptPageLimits) async throws -> SessionMessageTextCache.ResumableText {
        let read = try await SessionMessageTextReader.readChanged(session.conversation, resuming: nil, limits: limits)
        #expect(!read.resumed)
        return SessionMessageTextCache.ResumableText(text: read.text, state: try #require(read.resumeState))
    }

    /// Reads `session` resuming from `saved`, checks the text is exactly a clean full read's, and returns what to resume
    /// from next.
    @discardableResult
    private func expectCleanReadText(
        _ session: Session, resuming saved: SessionMessageTextCache.ResumableText, limits: TranscriptPageLimits,
        resumes: Bool, sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> (read: SessionMessageTextRead, next: SessionMessageTextCache.ResumableText) {
        let read = try await SessionMessageTextReader.readChanged(session.conversation, resuming: saved, limits: limits)
        let clean = try await SessionMessageTextReader.read(session.conversation, limits: limits)
        #expect(read.resumed == resumes, sourceLocation: sourceLocation)
        #expect(read.text == clean, sourceLocation: sourceLocation)
        #expect(read.text.entries.map(\.id) == clean.entries.map(\.id), sourceLocation: sourceLocation)
        let state = try #require(read.resumeState, sourceLocation: sourceLocation)
        #expect(state.isConsistent(with: read.text), sourceLocation: sourceLocation)
        return (read, SessionMessageTextCache.ResumableText(text: read.text, state: state))
    }

    @Test func repeatedSmallAppendsResumeAndEqualACleanRead() async throws {
        let session = try Session(
            (0..<9).map { $0.isMultiple(of: 3) ? Self.user("Ask \($0) Café 中文") : Self.assistant("Reply \($0) **bold** 👋") })
        defer { session.remove() }
        var saved = try await savedRead(of: session, limits: Self.smallPages)

        for number in 9..<30 {
            let line =
                switch number % 4 {
                case 0: Self.user("Ask \(number) naïve")
                case 1: Self.event()
                case 2: Self.toolCall("patch \(number)")
                default: Self.assistant("Reply \(number) 中文 🧪")
                }
            try session.append(lines: [line])
            let (read, next) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: true)
            #expect(read.decodedRecordCount <= Self.smallPages.maximumRecordCount * 2)
            #expect(read.decodedRecordCount < number + 1)
            saved = next
        }
    }

    @Test func codexWholeSessionLimitsResumeAppendsToo() async throws {
        let session = try Session((0..<50).map { Self.assistant("Message \($0)") })
        defer { session.remove() }
        var saved = try await savedRead(of: session, limits: SessionMessageTextReader.codexWholeSessionLimits)

        for number in 50..<53 {
            try session.append(lines: [Self.assistant("Appended \(number)")])
            saved = try await expectCleanReadText(
                session, resuming: saved, limits: SessionMessageTextReader.codexWholeSessionLimits, resumes: true
            ).next
        }
        #expect(saved.text.entries.last?.segments == ["Appended 52"])
    }

    @Test func aRunOfToolCallsAcrossTheFinalPagesStartMergesAsInACleanRead() async throws {
        let session = try Session([Self.user("Start"), Self.assistant("On it"), Self.toolCall("first"), Self.toolCall("second")])
        defer { session.remove() }
        var saved = try await savedRead(of: session, limits: Self.smallPages)

        for number in 0..<14 {
            try session.append(lines: [number == 9 ? Self.assistant("Between runs") : Self.toolCall("call \(number)")])
            saved = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: true).next
        }
        #expect(saved.text.entries.contains { $0.segments.count > 1 })
    }

    @Test(arguments: [
        ("partial JSON", "Second 中文 🧪", 30),
        ("partial UTF-8", "Second 中文 🧪", -1),
    ])
    func aPartialFinalRecordCompletedByAnAppendIsReadOnce(_ name: String, text: String, cutFromEnd: Int) async throws {
        let line = Data(Self.assistant(text).utf8)
        let cut: Int
        if cutFromEnd > 0 {
            cut = line.count - cutFromEnd
        } else {
            // One byte into "中", the first of its three.
            let character = Data("中".utf8)
            cut = try #require(line.range(of: character)).lowerBound + 1
        }
        let session = try Session([Self.assistant("First")])
        defer { session.remove() }
        try session.append(line.prefix(cut))
        let saved = try await savedRead(of: session, limits: SessionMessageTextReader.codexWholeSessionLimits)
        #expect(saved.text.entries.flatMap(\.segments) == ["First"])

        try session.append(line.dropFirst(cut) + Data("\n".utf8))
        let (read, _) = try await expectCleanReadText(
            session, resuming: saved, limits: SessionMessageTextReader.codexWholeSessionLimits, resumes: true
        )
        #expect(read.text.entries.flatMap(\.segments) == ["First", text])
    }

    @Test func aFinalRecordWithoutANewlineIsReadAgainWhenTheNextOneIsAppended() async throws {
        let session = try Session([])
        defer { session.remove() }
        try session.rewrite(Data(Self.assistant("No newline").utf8))
        let saved = try await savedRead(of: session, limits: Self.smallPages)
        #expect(saved.text.entries.flatMap(\.segments) == ["No newline"])

        try session.append(Data(("\n" + Self.assistant("After it") + "\n").utf8))
        let (read, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: true)
        #expect(read.text.entries.flatMap(\.segments) == ["No newline", "After it"])
    }

    @Test func oversizedRecordsAfterTheResumeAreJudgedAsInACleanRead() async throws {
        let limits = TranscriptPageLimits(targetEntryCount: 3, maximumRecordCount: 6, targetByteCount: 1 << 20, maximumRecordByteCount: 600)
        let session = try Session([Self.user("Before"), Self.assistant("Reply")])
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: limits)

        try session.append(lines: [
            Self.assistant("Too large " + String(repeating: "a", count: 700)),
            Self.event(700),
            Self.assistant("After the large records"),
        ])
        let (read, _) = try await expectCleanReadText(session, resuming: saved, limits: limits, resumes: true)
        #expect(read.text.entries.flatMap(\.segments) == ["Before", "Reply", "After the large records"])
    }

    @Test func anEarlierRecordAmendedAsTheFileGrowsIsReadInFull() async throws {
        let session = try Session([Self.assistant("Original"), Self.assistant("Kept"), Self.event()])
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: SessionMessageTextReader.codexWholeSessionLimits)

        try session.rewrite(
            SampleTranscriptLines.fileContents([
                Self.assistant("Amended!"), Self.assistant("Kept"), Self.event(), Self.assistant("After"),
            ]))
        let (read, _) = try await expectCleanReadText(
            session, resuming: saved, limits: SessionMessageTextReader.codexWholeSessionLimits, resumes: false
        )
        #expect(read.text.entries.flatMap(\.segments) == ["Amended!", "Kept", "After"])
    }

    @Test func anAmendmentBeforeTheFinalPageIsReadInFull() async throws {
        let session = try Session((0..<12).map { Self.assistant("Message \($0)") })
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)
        #expect(saved.state.finalPageRecord > 0)

        var lines = (0..<12).map { Self.assistant("Message \($0)") }
        lines[1] = Self.assistant("Message X")
        try session.rewrite(SampleTranscriptLines.fileContents(lines + [Self.assistant("Appended")]))
        let (read, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: false)
        #expect(read.text.entries[1].segments == ["Message X"])
    }

    @Test func aSameSizeRewriteIsReadInFull() async throws {
        let session = try Session([Self.assistant("Original")])
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)

        try session.rewrite(SampleTranscriptLines.fileContents([Self.assistant("Replaced")]))
        let (read, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: false)
        #expect(read.text.entries.flatMap(\.segments) == ["Replaced"])
    }

    @Test func aTruncatedFileIsReadInFullEvenOnceItGrowsPastItsSavedSize() async throws {
        let session = try Session([Self.assistant("One"), Self.assistant("Two")])
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)

        try session.rewrite(SampleTranscriptLines.fileContents([Self.assistant("One")]))
        let (shorter, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: false)
        #expect(shorter.text.entries.flatMap(\.segments) == ["One"])

        try session.append(lines: [Self.assistant("Three, longer than two")])
        let (longer, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: false)
        #expect(longer.text.entries.flatMap(\.segments) == ["One", "Three, longer than two"])
    }

    @Test func aReplacedFileIsReadInFull() async throws {
        let session = try Session([Self.assistant("Original")])
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)

        try SampleTranscriptLines.fileContents([Self.assistant("Original"), Self.assistant("Grown")]).write(
            to: session.file, options: .atomic)
        let (read, _) = try await expectCleanReadText(session, resuming: saved, limits: Self.smallPages, resumes: false)
        #expect(read.text.entries.flatMap(\.segments) == ["Original", "Grown"])
    }

    /// Where pages end decides which tool calls merge, so text read with other page limits is read again in full.
    @Test func textReadWithOtherPageLimitsIsReadInFull() async throws {
        let session = try Session((0..<12).map { $0.isMultiple(of: 2) ? Self.toolCall("patch \($0)") : Self.event() })
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)

        try session.append(lines: [Self.assistant("Appended")])
        try await expectCleanReadText(
            session, resuming: saved, limits: SessionMessageTextReader.codexWholeSessionLimits, resumes: false
        )
    }

    /// A full read keeps a resume state only for the bytes it read: any change to the file after it was indexed, even
    /// one of the same size, keeps none, as the text may come from other bytes than those hashed.
    @Test func aFullReadKeepsNoStateWhenTheFileChangedAfterItWasIndexed() async throws {
        let session = try Session([Self.assistant("Original")])
        defer { session.remove() }
        func indexedFingerprint() throws -> TranscriptFileFingerprint {
            let handle = try FileHandle(forReadingFrom: session.file)
            defer { try? handle.close() }
            return try TranscriptFileFingerprint(handle: handle)
        }
        func state(indexedAs fingerprint: TranscriptFileFingerprint) throws -> SessionMessageTextResumeState? {
            try CodexSessionTextResumer.state(
                of: session.file, indexedAs: fingerprint, finalPageRecord: 0, finalPageByteOffset: 0, committedEntryCount: 0,
                limits: Self.smallPages
            )
        }

        #expect(try state(indexedAs: try indexedFingerprint()) != nil)

        let beforeAppend = try indexedFingerprint()
        try session.append(lines: [Self.assistant("Appended")])
        #expect(try state(indexedAs: beforeAppend) == nil)

        let beforeAmendment = try indexedFingerprint()
        // Past the file system's timestamp granularity, so the amendment's modification time differs.
        try await Task.sleep(for: .milliseconds(20))
        let original = try Data(contentsOf: session.file)
        try session.rewrite(Data(original.map { $0 == UInt8(ascii: "O") ? UInt8(ascii: "Q") : $0 }))
        #expect(try Data(contentsOf: session.file).count == original.count)
        #expect(try state(indexedAs: beforeAmendment) == nil)
    }

    @Test func aReadOfAnotherProviderNeitherResumesNorKeepsAState() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("session.jsonl")
        try SampleTranscriptLines.fileContents(SampleTranscriptLines.claude).write(to: file)
        let claude = Conversation.fixture(provider: .claude, sourceFile: file)
        let codex = try Session([Self.assistant("Codex")])
        defer { codex.remove() }
        let saved = try await savedRead(of: codex, limits: SessionMessageTextReader.codexWholeSessionLimits)

        let read = try await SessionMessageTextReader.readChanged(claude, resuming: saved)

        #expect(!read.resumed)
        #expect(read.resumeState == nil)
        #expect(read.text == (try await SessionMessageTextReader.read(claude)))
    }

    @Test func aCancelledResumeThrows() async throws {
        let session = try Session((0..<12).map { Self.assistant("Message \($0)") })
        defer { session.remove() }
        let saved = try await savedRead(of: session, limits: Self.smallPages)
        try session.append(lines: [Self.assistant("Appended")])

        let task = Task {
            try? await Task.sleep(for: .seconds(60))
            return try await SessionMessageTextReader.readChanged(session.conversation, resuming: saved, limits: Self.smallPages)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) { try await task.value }
    }
}
