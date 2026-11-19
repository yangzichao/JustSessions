import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptReadingRequestTests {
    @MainActor
    private struct Reader {
        let files: TranscriptPagingFixture
        let fixture: TranscriptScrollViewFixture
        let store: ConversationStore
        let requests: SessionReadingRequests
        let conversation: Conversation

        func show(_ conversation: Conversation? = nil) {
            fixture.showReader(conversation ?? self.conversation, store: store, readingRequests: requests)
        }

        func showsAtTop(_ entryID: Int) -> Bool {
            guard let scrollView = fixture.readerScrollView, let controller = fixture.positionController, !controller.isRestoring,
                let frame = controller.entryFrameInClipView(at: entryID)
            else { return false }
            return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
        }

        var visiblePosition: TranscriptReadingPosition? { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) }

        func waitUntilEmpty() async throws {
            for _ in 0..<200 {
                if fixture.readerScrollView == nil, try await fixture.hasAccessibilityElement(labeled: "No messages yet") { return }
                try await Task.sleep(for: .milliseconds(25))
            }
            Issue.record("The reader never showed No messages yet")
        }

        func close() {
            fixture.close()
            files.remove()
        }
    }

    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    private func bookmark(_ letter: String, at record: Int) -> MessageBookmark {
        MessageBookmark(letter: letter, entryID: id(record), kind: .assistant, snippet: "Message \(record), line 0:")
    }

    private static let fiveMoreRecords = Data(
        TranscriptPagingFixture.data(count: 605, lineCounts: [603: 60, 604: 60]).dropFirst(TranscriptPagingFixture.data(count: 600).count)
    )

    private func makeReader(
        bookmarks: [MessageBookmark] = [], at position: TranscriptReadingPosition? = nil,
        waitingFor navigation: SessionReadingNavigation? = nil,
        lineCount: Int = 1, showing: Bool = true
    ) async throws -> Reader {
        let files = try TranscriptPagingFixture(count: 600, lineCount: lineCount)
        let fixture = try TranscriptScrollViewFixture()
        MessageBookmarks(bookmarksByConversationID: [files.conversation.id: bookmarks]).save(to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        if let position { fixture.positionStore.record(position, for: files.conversation.id) }
        let requests = SessionReadingRequests()
        if let navigation { requests.request(navigation) }
        let reader = Reader(files: files, fixture: fixture, store: store, requests: requests, conversation: files.conversation)
        if showing { reader.show() }
        return reader
    }

    @Test func anAdjacentRequestGoesOnFromTheReadersOrigin() async throws {
        let reader = try await makeReader(
            bookmarks: [bookmark("a", at: 540), bookmark("b", at: 570)],
            at: .entry(index: id(500), offset: -6), lineCount: 4)
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.showsAtTop(id(500)) }

        reader.requests.request(.adjacentBookmark(forward: true))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(540)) }
        #expect(reader.showsAtTop(id(540)))

        reader.requests.request(.adjacentBookmark(forward: true))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(570)) }
        #expect(reader.showsAtTop(id(570)))
        #expect(reader.requests.pendingNavigation == nil)
    }

    @Test func anEntryRequestForALoadedMessageIsTheSeekTarget() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }

        reader.requests.request(.entry(id(560)))

        try await reader.fixture.waitUntil { reader.showsAtTop(id(560)) }
        #expect(reader.showsAtTop(id(560)))
        #expect(reader.fixture.positionController?.seekTarget == id(560))
    }

    @Test func anEntryRequestForAnUnloadedMessageLoadsItsPage() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        reader.requests.requestFind()
        try await reader.fixture.waitUntil { !reader.fixture.textFieldValues.isEmpty }
        #expect(!reader.fixture.textFieldValues.isEmpty)

        reader.requests.request(.entry(id(50)))

        try await reader.fixture.waitUntil { reader.showsAtTop(id(50)) }
        #expect(reader.showsAtTop(id(50)))
        #expect(reader.fixture.positionController?.seekTarget == id(50))
        #expect(reader.fixture.textFieldValues.isEmpty)
    }

    @Test func anEntryRequestPastTheLoadedPagesReadsTheFileAgain() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        try reader.files.append(Self.fiveMoreRecords)

        reader.requests.request(.entry(id(603)))

        try await reader.fixture.waitUntil { reader.showsAtTop(id(603)) }
        #expect(reader.showsAtTop(id(603)))
        #expect(reader.fixture.positionController?.seekTarget == id(603))
    }

    @Test func aBookmarkAddedPastTheLoadedPagesIsFoundNotMissing() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        try reader.files.append(Self.fiveMoreRecords)
        let page = try await TranscriptPageSource(file: reader.files.file, provider: .codex).read(.latest)
        let entry = try #require(page.entries.first { $0.id == id(603) })
        #expect(reader.store.toggleMessageBookmark(on: entry, in: reader.conversation) != .allLettersInUse)

        reader.requests.request(.adjacentBookmark(forward: true))

        try await reader.fixture.waitUntil { reader.showsAtTop(id(603)) }
        #expect(reader.showsAtTop(id(603)))
        #expect(reader.fixture.positionController?.seekTarget == id(603))
        #expect(
            try await !reader.fixture.hasAccessibilityElement(
                labeled: "Bookmark a's message is no longer in this conversation. This is where it was."
            ))
    }

    @Test func aFileChangeDuringAnEntryJumpStillLands() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }

        reader.requests.request(.entry(id(50)))
        reader.fixture.hostingView.layoutSubtreeIfNeeded()
        #expect(reader.requests.pendingNavigation == nil)
        reader.show(reader.files.conversation)
        reader.fixture.hostingView.layoutSubtreeIfNeeded()

        try await reader.fixture.waitUntil { reader.showsAtTop(id(50)) }
        #expect(reader.showsAtTop(id(50)))
        #expect(reader.fixture.positionController?.seekTarget == id(50))
    }

    @Test func aRequestIsNotReplayedByARebuiltReader() async throws {
        let reader = try await makeReader()
        defer { reader.close() }
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        reader.requests.request(.entry(id(560)))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(560)) }
        let scrollView = try #require(reader.fixture.readerScrollView)
        try await reader.fixture.scroll(scrollView, to: scrollView.documentView?.frame.height ?? 100_000)
        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }

        let content = try Data(contentsOf: reader.files.file)
        try Data().write(to: reader.files.file)
        reader.show(reader.files.conversation)
        try await reader.waitUntilEmpty()
        try content.write(to: reader.files.file)
        reader.show(reader.files.conversation)

        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        #expect(reader.visiblePosition == .bottom)
        #expect(!reader.showsAtTop(id(560)))
        #expect(reader.fixture.positionController?.seekTarget == nil)
    }

    @Test func pressesWhileTheFirstPageLoadsAddUp() async throws {
        let bookmarks = [bookmark("a", at: 300), bookmark("b", at: 320)]
        let reader = try await makeReader(
            bookmarks: bookmarks, at: .entry(index: id(300), offset: -6),
            waitingFor: .bookmark(bookmarks[0]))
        defer { reader.close() }
        reader.fixture.hostingView.layoutSubtreeIfNeeded()
        #expect(reader.fixture.readerScrollView == nil)

        try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: reader.fixture.window)).goToAdjacentBookmark(true)

        #expect(reader.requests.pendingNavigation == .bookmark(bookmarks[1]))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(320)) }
        #expect(reader.showsAtTop(id(320)))
        #expect(reader.fixture.positionController?.seekTarget == id(320))
    }

    @Test func pressesWhileTheFirstPageLoadsGoOnFromWhereTheWindowOpened() async throws {
        let reader = try await makeReader(
            bookmarks: [bookmark("a", at: 100), bookmark("b", at: 540), bookmark("c", at: 570)],
            at: .entry(index: id(500), offset: -6), lineCount: 4)
        defer { reader.close() }
        reader.fixture.hostingView.layoutSubtreeIfNeeded()
        #expect(reader.fixture.readerScrollView == nil)

        let target = try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: reader.fixture.window))
        target.goToAdjacentBookmark(true)
        target.goToAdjacentBookmark(true)

        try await reader.fixture.waitUntil { reader.showsAtTop(id(570)) }
        #expect(reader.showsAtTop(id(570)))
        #expect(reader.fixture.positionController?.seekTarget == id(570))
    }

    @Test func aWindowOpenedAtAGoneBookmarkShowsTheLatestMessages() async throws {
        let gone = bookmark("a", at: 700)
        let reader = try await makeReader(
            bookmarks: [gone], at: .entry(index: gone.entryID, offset: -6), waitingFor: .bookmark(gone),
            showing: false)
        defer { reader.close() }
        try reader.files.append(
            Data((#"{"timestamp":"2026-10-02T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count"}}"# + "\n").utf8))
        reader.show()

        try await reader.fixture.waitUntil { reader.visiblePosition == .bottom }
        #expect(reader.visiblePosition == .bottom)
        #expect(
            try await reader.fixture.hasAccessibilityElement(
                labeled: "Bookmark a's message is no longer in this conversation. This is where it was."
            ))
        #expect(reader.requests.pendingNavigation == nil)
    }

    @Test func aRequestToAnEmptyReaderReadsTheFileAgain() async throws {
        let reader = try await makeReader(showing: false)
        defer { reader.close() }
        let content = try Data(contentsOf: reader.files.file)
        try Data().write(to: reader.files.file)
        reader.show()
        try await reader.waitUntilEmpty()

        try content.write(to: reader.files.file)
        reader.requests.request(.entry(id(50)))

        try await reader.fixture.waitUntil { reader.showsAtTop(id(50)) }
        #expect(reader.showsAtTop(id(50)))
        #expect(reader.fixture.positionController?.seekTarget == id(50))
    }
}
