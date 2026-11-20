import AppKit
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TranscriptBookmarkJumpTests {
    @MainActor
    private struct Reader {
        let files: TranscriptPagingFixture
        let fixture: TranscriptScrollViewFixture
        let paging: TranscriptPagingModel
        let store: ConversationStore
        let bookmarkState: TranscriptBookmarkState
        let searchState: TranscriptSearchState
        let scrollView: NSScrollView
        let controller: TranscriptScrollPositionController

        var commands: TranscriptBookmarkCommandTarget {
            get throws { try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: fixture.window)) }
        }

        var savedBookmarks: [MessageBookmark] {
            store.messageBookmarks.bookmarks(forConversationID: files.conversation.id)
        }

        func showsAtTop(_ entryID: Int) -> Bool {
            guard !paging.isLoading, !controller.isRestoring, let frame = controller.entryFrameInClipView(at: entryID) else { return false }
            return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
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

    private func openReader(bookmarks: [MessageBookmark] = [], at position: TranscriptReadingPosition? = nil) async throws -> Reader {
        let files = try TranscriptPagingFixture(count: 600)
        let fixture = try TranscriptScrollViewFixture()
        let conversation = files.conversation
        MessageBookmarks(bookmarksByConversationID: [conversation.id: bookmarks]).save(to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        let paging = TranscriptPagingModel()
        paging.refresh(conversation, position: position)
        try await expectEventually { !paging.isLoading }
        if let position { fixture.positionStore.record(position, for: conversation.id) }
        let bookmarkState = TranscriptBookmarkState()
        let searchState = TranscriptSearchState()
        let scrollView = try await fixture.show(
            conversation, transcript: try #require(paging.transcript), paging: paging,
            searchState: searchState, store: store, bookmarkState: bookmarkState)
        let controller = try #require(fixture.positionController)
        try await fixture.waitUntil { !paging.isLoading && !controller.isRestoring }
        return Reader(
            files: files, fixture: fixture, paging: paging, store: store, bookmarkState: bookmarkState,
            searchState: searchState, scrollView: scrollView, controller: controller)
    }

    private func showsAtTop(_ entryID: Int, in fixture: TranscriptScrollViewFixture) -> Bool {
        guard let scrollView = fixture.readerScrollView, let controller = fixture.positionController, !controller.isRestoring,
            let frame = controller.entryFrameInClipView(at: entryID)
        else { return false }
        return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
    }

    @Test func goingToALoadedBookmarkPutsItsMessageAtTheTop() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 560)])
        defer { reader.close() }

        try reader.commands.goToAdjacentBookmark(false)

        #expect(reader.controller.seekTarget == id(560))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(560)) }
        #expect(reader.showsAtTop(id(560)))
        #expect(reader.savedBookmarks.first?.snippet == "Message 560, line 0: keep this reading position.")
    }

    @Test func goingToAnUnloadedBookmarkLoadsItsPage() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 50)])
        defer { reader.close() }

        try reader.commands.goToAdjacentBookmark(true)

        #expect(reader.bookmarkState.loadingJump?.entryID == id(50))
        #expect(reader.controller.seekTarget == id(50))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(50)) }
        #expect(reader.showsAtTop(id(50)))
        #expect(reader.bookmarkState.loadingJump == nil)
        #expect(reader.controller.seekTarget == id(50))
    }

    @Test func nextAndPreviousWrapAroundTheEnds() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 540), bookmark("b", at: 570)])
        defer { reader.close() }

        var seekTargets: [Int?] = []
        for forward in [true, true, true, false, false] {
            try reader.commands.goToAdjacentBookmark(forward)
            let seekTarget = reader.controller.seekTarget
            seekTargets.append(seekTarget)
            try await reader.fixture.waitUntil { seekTarget.map(reader.showsAtTop) == true }
        }

        #expect(seekTargets == [id(540), id(570), id(540), id(570), id(540)])
    }

    @Test func rapidRepeatedNextVisitsEachBookmarkInTurn() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 540), bookmark("b", at: 555), bookmark("c", at: 570)])
        defer { reader.close() }

        let commands = try reader.commands
        commands.goToAdjacentBookmark(true)
        commands.goToAdjacentBookmark(true)
        commands.goToAdjacentBookmark(true)

        #expect(reader.controller.seekTarget == id(570))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(570)) }
        #expect(reader.showsAtTop(id(570)))
        #expect(reader.controller.seekTarget == id(570))
    }

    @Test func commandDRightAfterAJumpNearTheEndActsOnTheJumpedToMessage() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 598)])
        defer { reader.close() }
        try reader.commands.goToAdjacentBookmark(true)
        try await reader.fixture.waitUntil { !reader.paging.isLoading && !reader.controller.isRestoring }
        #expect(reader.controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first != id(598))
        #expect(reader.controller.seekTarget == id(598))

        try reader.commands.toggleBookmark()

        #expect(reader.savedBookmarks.isEmpty)
    }

    @Test func commandDBookmarksTheMessageAtTheTopAndRemovesItAgain() async throws {
        let reader = try await openReader()
        defer { reader.close() }
        let clipView = reader.scrollView.contentView
        try await reader.fixture.scroll(reader.scrollView, to: (clipView.documentRect.height - clipView.bounds.height) / 2)
        try await reader.fixture.waitUntil { !reader.paging.isLoading && !reader.controller.isRestoring }
        let top = try #require(
            reader.controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first)

        try reader.commands.toggleBookmark()

        #expect(reader.savedBookmarks.map(\.letter) == ["a"])
        #expect(reader.savedBookmarks.first?.entryID == top)

        try reader.commands.toggleBookmark()

        #expect(reader.savedBookmarks.isEmpty)
    }

    @Test func aJumpThatLoadsAPageClosesFindAndKeepsItsQuery() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 50)])
        defer { reader.close() }
        reader.searchState.show()
        reader.searchState.query = "Message 59"
        try await reader.fixture.waitUntil {
            !reader.searchState.isSearching && reader.searchState.selectedMatch != nil && !reader.controller.isRestoring
        }

        try reader.commands.goToAdjacentBookmark(true)

        #expect(!reader.searchState.isPresented)
        #expect(reader.searchState.query == "Message 59")
        try await reader.fixture.waitUntil { reader.showsAtTop(id(50)) }
        #expect(reader.showsAtTop(id(50)))
    }

    @Test func aJumpToALoadedMessageKeepsFindOpen() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 560)])
        defer { reader.close() }
        reader.searchState.show()
        reader.searchState.query = "Message 59"
        try await reader.fixture.waitUntil {
            !reader.searchState.isSearching && reader.searchState.selectedMatch != nil && !reader.controller.isRestoring
        }
        let selectedMatch = reader.searchState.selectedMatch

        try reader.commands.goToAdjacentBookmark(true)

        try await reader.fixture.waitUntil { reader.showsAtTop(id(560)) }
        #expect(reader.showsAtTop(id(560)))
        #expect(reader.searchState.isPresented)
        #expect(reader.searchState.selectedMatch == selectedMatch)
    }

    @Test func aJumpWhileAPageLoadsAsksForItsOwnPage() async throws {
        let start = TranscriptReadingPosition.startOfEntry(id(300))
        let reader = try await openReader(bookmarks: [bookmark("a", at: 340)], at: start)
        defer { reader.close() }
        reader.paging.later(preserving: start)
        #expect(reader.paging.isLoading)

        try reader.commands.goToAdjacentBookmark(true)

        #expect(reader.bookmarkState.loadingJump?.entryID == id(340))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(340)) }
        #expect(reader.showsAtTop(id(340)))
        #expect(reader.controller.seekTarget == id(340))
    }

    @Test func aMissingBookmarkStaysListedShowsWhereItWasAndPreviousMovesPastIt() async throws {
        let rewritten = MessageBookmark(letter: "b", entryID: id(540), kind: .assistant, snippet: "A reply rewritten since")
        let reader = try await openReader(bookmarks: [bookmark("a", at: 520), rewritten])
        defer { reader.close() }

        try reader.commands.goToAdjacentBookmark(false)

        #expect(reader.bookmarkState.notice == .missing(rewritten))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(540)) }
        #expect(reader.showsAtTop(id(540)))
        #expect(reader.savedBookmarks.contains(rewritten))

        try reader.commands.goToAdjacentBookmark(false)

        #expect(reader.controller.seekTarget == id(520))
        try await reader.fixture.waitUntil { reader.showsAtTop(id(520)) }
        #expect(reader.showsAtTop(id(520)))
        #expect(reader.bookmarkState.notice == nil)
    }

    @Test func togglingWithAll26LettersUsedSaysWhy() async throws {
        let bookmarks = MessageBookmarks.letters.enumerated().map { record, letter in bookmark(letter, at: record) }
        let reader = try await openReader(bookmarks: bookmarks)
        defer { reader.close() }

        try reader.commands.toggleBookmark()

        #expect(reader.bookmarkState.notice == .allLettersInUse)
        #expect(reader.savedBookmarks == bookmarks)
    }

    @Test func nextWithNoBookmarksSaysSo() async throws {
        let reader = try await openReader()
        defer { reader.close() }

        try reader.commands.goToAdjacentBookmark(true)

        #expect(reader.bookmarkState.notice == .noBookmarks)
    }

    @Test func goingToFirstMessageEndsALoadingJump() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 300)])
        defer { reader.close() }
        var startedJump = false

        try await reader.fixture.pressButton(labeled: "First message") {
            TranscriptBookmarkTargetRegistry.shared.target(keyWindow: reader.fixture.window)?.goToAdjacentBookmark(true)
            startedJump = reader.bookmarkState.loadingJump != nil
        }

        #expect(startedJump)
        try await reader.fixture.waitUntil {
            !reader.paging.isLoading && reader.fixture.visiblePosition(in: reader.scrollView)?.entryIndex == id(0)
        }
        #expect(reader.fixture.visiblePosition(in: reader.scrollView)?.entryIndex == id(0))
        #expect(reader.bookmarkState.loadingJump == nil)
        #expect(reader.bookmarkState.notice == nil)
        #expect(reader.controller.seekTarget == nil)
    }

    @Test func aBookmarkedMessageShowsItsLetter() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 598)])
        defer { reader.close() }

        #expect(try await reader.fixture.hasAccessibilityElement(labeled: "Bookmark a"))
    }

    @Test func aBookmarkOnlyHiddenRecordsFollowShowsTheLatestMessages() async throws {
        let files = try TranscriptPagingFixture(count: 300)
        defer { files.remove() }
        let tokenCount = #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"event_msg","payload":{"type":"token_count"}}"# + "\n"
        try (TranscriptPagingFixture.data(count: 300) + Data(String(repeating: tokenCount, count: 300).utf8)).write(to: files.file)
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        let gone = MessageBookmark(letter: "a", entryID: id(450), kind: .assistant, snippet: "Message 450, line 0:")
        MessageBookmarks(bookmarksByConversationID: [files.conversation.id: [gone]]).save(to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        fixture.positionStore.record(.startOfEntry(id(0)), for: files.conversation.id)
        fixture.showReader(files.conversation, store: store)
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:))?.entryIndex == id(0) }

        try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: fixture.window)).goToAdjacentBookmark(true)

        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }
        #expect(fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom)
        #expect(
            try await fixture.hasAccessibilityElement(
                labeled: "Bookmark a's message is no longer in this conversation. This is where it was."
            ))
        #expect(store.messageBookmarks.bookmarks(forConversationID: files.conversation.id) == [gone])
    }

    private func jumpWhileAMatchRevealLoads(fileChanges: Bool) async throws {
        let files = try TranscriptPagingFixture(count: 600)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        MessageBookmarks(bookmarksByConversationID: [files.conversation.id: [bookmark("a", at: 50)]]).save(
            to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        fixture.showReader(files.conversation, store: store)
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }
        let commands = try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: fixture.window))
        let reveal = TranscriptMatchReveal(conversationID: files.conversation.id, entryID: id(300), query: "Message 300")

        fixture.showReader(files.conversation, matchReveal: reveal, store: store)
        fixture.hostingView.layoutSubtreeIfNeeded()
        commands.goToAdjacentBookmark(true)
        if fileChanges {
            fixture.showReader(files.conversation, matchReveal: reveal, store: store)
            fixture.hostingView.layoutSubtreeIfNeeded()
        }

        try await fixture.waitUntil { showsAtTop(id(50), in: fixture) }
        #expect(showsAtTop(id(50), in: fixture))
        #expect(fixture.positionController?.seekTarget == id(50))
        #expect(fixture.textFieldValues.isEmpty)
        #expect(
            try await !fixture.hasAccessibilityElement(
                labeled: "Bookmark a's message is no longer in this conversation. This is where it was."
            ))
    }

    @Test func aJumpMadeWhileAMatchRevealLoadsLandsWithFindClosed() async throws {
        try await jumpWhileAMatchRevealLoads(fileChanges: false)
    }

    @Test func aFileChangeAfterAJumpThatReplacedAMatchRevealStillLandsOnTheBookmark() async throws {
        try await jumpWhileAMatchRevealLoads(fileChanges: true)
    }

    @Test func aFileChangeDuringAJumpStillLandsOnTheBookmark() async throws {
        let files = try TranscriptPagingFixture(count: 600)
        defer { files.remove() }
        let fixture = try TranscriptScrollViewFixture()
        defer { fixture.close() }
        MessageBookmarks(bookmarksByConversationID: [files.conversation.id: [bookmark("a", at: 50)]]).save(
            to: fixture.settings.userDefaults)
        let store = ConversationStore(adapters: [], userDefaults: fixture.settings.userDefaults, startsBackgroundPolling: false)
        fixture.showReader(files.conversation, store: store)
        try await fixture.waitUntil { fixture.readerScrollView.flatMap(fixture.visiblePosition(in:)) == .bottom }

        try #require(TranscriptBookmarkTargetRegistry.shared.target(keyWindow: fixture.window)).goToAdjacentBookmark(true)
        fixture.showReader(files.conversation, store: store)
        fixture.hostingView.layoutSubtreeIfNeeded()

        try await fixture.waitUntil { showsAtTop(id(50), in: fixture) }
        #expect(showsAtTop(id(50), in: fixture))
        #expect(fixture.positionController?.seekTarget == id(50))
    }

    @Test func theHighlightIsOnTheMessageCommandDBookmarksAsTheReaderScrolls() async throws {
        let reader = try await openReader()
        defer { reader.close() }
        let clipView = reader.scrollView.contentView
        let target = reader.bookmarkState.target

        for fraction in [0.5, 0.2] {
            try await reader.fixture.scroll(reader.scrollView, to: (clipView.documentRect.height - clipView.bounds.height) * fraction)
            try await reader.fixture.waitUntil {
                !reader.paging.isLoading && !reader.controller.isRestoring
                    && target.shown?.entryID
                        == reader.controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first
            }
            let shown = try #require(target.shown)
            #expect(shown.frame == reader.controller.entryFrameInStack(at: shown.entryID))

            try reader.commands.toggleBookmark()

            #expect(reader.savedBookmarks.contains { $0.entryID == shown.entryID })
        }
        #expect(reader.savedBookmarks.count == 2)
    }

    @Test func afterAJumpNearTheEndTheHighlightIsOnTheJumpedToMessage() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 598)])
        defer { reader.close() }

        try reader.commands.goToAdjacentBookmark(true)
        try await reader.fixture.waitUntil {
            !reader.paging.isLoading && !reader.controller.isRestoring && reader.bookmarkState.target.shown?.entryID == id(598)
        }

        #expect(reader.bookmarkState.target.shown?.entryID == id(598))
        #expect(reader.controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight).first != id(598))
    }

    private func pointerLocation(over entryID: Int, x: CGFloat? = nil, in reader: Reader) throws -> CGPoint {
        let frame = try #require(reader.controller.entryFrameInClipView(at: entryID))
        let point = CGPoint(x: x ?? frame.midX, y: frame.midY)
        return reader.scrollView.contentView.convert(point, to: nil)
    }

    private func visibleMessages(in reader: Reader) -> [Int] {
        reader.controller.visibleEntryIDs(minimumVisibleHeight: MessageBookmarkNavigation.minimumVisibleHeight)
    }

    @Test func thePointerChoosesTheMessageBeingRead() async throws {
        let reader = try await openReader()
        defer { reader.close() }
        let visible = visibleMessages(in: reader)
        try #require(visible.count >= 3)
        let underPointer = visible[2]

        reader.controller.pointerMoved(to: try pointerLocation(over: underPointer, x: 4, in: reader))
        try await reader.fixture.waitUntil { reader.bookmarkState.target.shown?.entryID == underPointer }
        try reader.commands.toggleBookmark()

        #expect(reader.savedBookmarks.map(\.entryID) == [underPointer])
        reader.controller.pointerLeft()
        try await reader.fixture.waitUntil { reader.bookmarkState.target.shown?.entryID == visible[0] }
    }

    @Test func aJumpWinsUntilThePointerMovesAgain() async throws {
        let reader = try await openReader(bookmarks: [bookmark("a", at: 560)])
        defer { reader.close() }
        let other = visibleMessages(in: reader)[1]
        reader.controller.pointerMoved(to: try pointerLocation(over: other, in: reader))
        try await reader.fixture.waitUntil { reader.bookmarkState.target.shown?.entryID == other }

        try reader.commands.goToAdjacentBookmark(true)
        try await reader.fixture.waitUntil { showsAtTopNow(id(560), in: reader) }

        #expect(reader.bookmarkState.target.shown?.entryID == id(560))
        let underPointer = visibleMessages(in: reader)[2]
        reader.controller.pointerMoved(to: try pointerLocation(over: underPointer, in: reader))
        try await reader.fixture.waitUntil { reader.bookmarkState.target.shown?.entryID == underPointer }
    }

    private func showsAtTopNow(_ entryID: Int, in reader: Reader) -> Bool {
        !reader.paging.isLoading && !reader.controller.isRestoring && reader.showsAtTop(entryID)
    }

    @Test func theMarksClickTogglesItsMessagesBookmarkAndItsMenuEditsIt() async throws {
        let reader = try await openReader()
        defer { reader.close() }
        let message = visibleMessages(in: reader)[1]
        let commands = try reader.commands

        commands.toggleBookmarkOnEntry(message)
        #expect(reader.savedBookmarks.map(\.entryID) == [message])
        try reader.commands.toggleBookmarkOnEntry(message)
        #expect(reader.savedBookmarks.isEmpty)

        try reader.commands.editBookmarkOnEntry(message)
        #expect(reader.savedBookmarks.map(\.entryID) == [message])
        try await reader.fixture.waitUntil { reader.bookmarkState.editor.request != nil }
    }
}
