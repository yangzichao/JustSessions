import AppKit
import Testing

@testable import JustSessions

/// ⌘D, ⌘', and ⇧⌘' in a tab (TRM-74): ⌘D bookmarks the newest message in the session's file, ⌘' and ⇧⌘' hand the jump to
/// its reading window, and a notice over the terminal says what happened.
@MainActor
@Suite(.serialized)
struct TerminalTabBookmarksTests {
    @MainActor
    private struct Harness {
        let settings: IsolatedUserDefaults
        let store: ConversationStore
        let readingWindows = SessionReadingWindowManager()
        let tab: TerminalSession
        let conversation: Conversation?

        init(provider: ConversationProvider? = .codex, conversation: Conversation?, bookmarks: [MessageBookmark] = []) throws {
            WindowAnimations.disable()
            settings = try IsolatedUserDefaults()
            if let conversation {
                MessageBookmarks(bookmarksByConversationID: [conversation.id: bookmarks]).save(to: settings.userDefaults)
            }
            store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
            self.conversation = conversation
            tab = TerminalSession(
                engine: .swiftTerm,
                conversation: conversation,
                provider: provider,
                projectPath: "/tmp/terminal-tab-bookmarks",
                action: provider == nil ? nil : .resume,
                displayTitle: "Tab bookmarks",
                command: NativeCLICommand(executablePath: "/usr/bin/true", arguments: [], workingDirectory: "/tmp", environment: [])
            )
            // Selected, so a command that changed the selected tab would show.
            store.openTerminal(tab)
        }

        var bookmarks: TerminalTabBookmarks { TerminalTabBookmarks(store: store, readingWindows: readingWindows) }

        var savedBookmarks: [MessageBookmark] {
            conversation.map { store.messageBookmarks.bookmarks(forConversationID: $0.id) } ?? []
        }

        func toggle() async throws {
            let task = try #require(bookmarks.toggleLatestMessage(in: tab))
            await task.value
        }

        /// The session's reading window, if one is open; opening it again without a request only brings it forward.
        func openController() throws -> SessionReadingWindowController {
            let conversation = try #require(conversation)
            return try #require(readingWindows.open(conversation, store: store).windowController as? SessionReadingWindowController)
        }

        func close() {
            store.closeAllTerminals()
            settings.removeSuite()
        }
    }

    private func id(_ record: Int) -> Int { TranscriptPageIdentity.entryID(record: record, part: 0) }

    private func bookmark(_ letter: String, at record: Int) -> MessageBookmark {
        MessageBookmark(letter: letter, entryID: id(record), kind: .assistant, snippet: "Message \(record), line 0:")
    }

    @Test func commandDBookmarksTheNewestMessageAndSaysWhich() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        try await harness.toggle()

        let saved = try #require(harness.savedBookmarks.first)
        #expect(harness.savedBookmarks.count == 1)
        #expect(saved.letter == "a")
        #expect(saved.entryID == id(29))
        #expect(saved.kind == .assistant)
        #expect(harness.tab.bookmarkNotices.notice == .added(saved, assistantName: "Codex"))
        #expect(harness.store.selectedTerminalID == harness.tab.id)
    }

    @Test func shiftCommandDBookmarksTheNewestMessageAndOpensItsEditor() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        let task = try #require(harness.bookmarks.editLatestMessage(in: harness.tab))
        await task.value

        let saved = try #require(harness.savedBookmarks.first)
        #expect(saved.entryID == id(29))
        #expect(harness.tab.bookmarkNotices.editor.request?.bookmark == saved)
        #expect(harness.tab.bookmarkNotices.editor.request?.conversation.id == files.conversation.id)
        #expect(harness.tab.bookmarkNotices.notice == nil)
        #expect(harness.store.selectedTerminalID == harness.tab.id)
    }

    /// Unlike ⌘D, it never removes: a bookmarked newest message keeps its bookmark and its label.
    @Test func shiftCommandDKeepsAnExistingBookmark() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        var labelled = bookmark("c", at: 29)
        labelled.label = "Where it ended"
        let harness = try Harness(conversation: files.conversation, bookmarks: [labelled])
        defer { harness.close() }

        let task = try #require(harness.bookmarks.editLatestMessage(in: harness.tab))
        await task.value

        #expect(harness.savedBookmarks == [labelled])
        #expect(harness.tab.bookmarkNotices.editor.request?.bookmark == labelled)
    }

    @Test func shiftCommandDWithAll26LettersUsedSaysWhyAndOpensNothing() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let full = MessageBookmarks.letters.enumerated().map { bookmark($1, at: $0) }
        let harness = try Harness(conversation: files.conversation, bookmarks: full)
        defer { harness.close() }

        let task = try #require(harness.bookmarks.editLatestMessage(in: harness.tab))
        await task.value

        #expect(harness.tab.bookmarkNotices.notice == .allLettersInUse)
        #expect(harness.tab.bookmarkNotices.editor.request == nil)
    }

    @Test func aSecondCommandDRemovesIt() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }
        try await harness.toggle()
        let saved = try #require(harness.savedBookmarks.first)

        try await harness.toggle()

        #expect(harness.savedBookmarks.isEmpty)
        #expect(harness.tab.bookmarkNotices.notice == .removed(saved, assistantName: "Codex"))
    }

    /// The second press waits for the first's read and toggle, so it removes what the first added.
    @Test func rapidPressesRunInOrder() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        harness.bookmarks.toggleLatestMessage(in: harness.tab)
        let second = try #require(harness.bookmarks.toggleLatestMessage(in: harness.tab))
        await second.value

        #expect(harness.savedBookmarks.isEmpty)
        guard case .removed(let bookmark, _)? = harness.tab.bookmarkNotices.notice else {
            Issue.record("Expected a removed notice, got \(String(describing: harness.tab.bookmarkNotices.notice))")
            return
        }
        #expect(bookmark.entryID == id(29))

        // Reads on one tab's reader tend to finish in order anyway, so a slower first command shows the queue waits.
        var ran: [String] = []
        harness.tab.bookmarkNotices.enqueue {
            try? await Task.sleep(for: .milliseconds(100))
            ran.append("first")
        }
        await harness.tab.bookmarkNotices.enqueue { ran.append("second") }.value
        #expect(ran == ["first", "second"])
    }

    @Test func commandDPagesBackPastToolCalls() async throws {
        let files = try TranscriptPagingFixture(count: 5)
        defer { files.remove() }
        try files.append(SampleTranscriptLines.fileContents(Array(repeating: SampleTranscriptLines.codex[2], count: 400)))
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        try await harness.toggle()

        #expect(harness.savedBookmarks.map(\.entryID) == [id(4)])
        #expect(harness.savedBookmarks.first?.snippet.hasPrefix("Message 4, line 0:") == true)
    }

    @Test func aPlainTerminalAndAnUnlinkedTabSayWhy() throws {
        let plain = try Harness(provider: nil, conversation: nil)
        defer { plain.close() }
        #expect(plain.bookmarks.toggleLatestMessage(in: plain.tab) == nil)
        #expect(plain.tab.bookmarkNotices.notice == .plainTerminal)
        plain.tab.bookmarkNotices.dismiss()
        plain.bookmarks.goToAdjacentBookmark(forward: true, from: plain.tab)
        #expect(plain.tab.bookmarkNotices.notice == .plainTerminal)

        let unlinked = try Harness(provider: .claude, conversation: nil)
        defer { unlinked.close() }
        #expect(unlinked.bookmarks.toggleLatestMessage(in: unlinked.tab) == nil)
        #expect(unlinked.tab.bookmarkNotices.notice == .notLinkedYet)
        unlinked.tab.bookmarkNotices.dismiss()
        unlinked.bookmarks.goToAdjacentBookmark(forward: false, from: unlinked.tab)
        #expect(unlinked.tab.bookmarkNotices.notice == .notLinkedYet)

        #expect(plain.store.messageBookmarks == MessageBookmarks())
        #expect(unlinked.store.messageBookmarks == MessageBookmarks())
    }

    @Test func anEmptySessionSaysSo() async throws {
        let files = try TranscriptPagingFixture(count: 0)
        defer { files.remove() }
        try SampleTranscriptLines.fileContents(
            [SampleTranscriptLines.codex[0]] + Array(repeating: SampleTranscriptLines.codex[2], count: 5)
        )
        .write(to: files.file)
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        try await harness.toggle()

        #expect(harness.tab.bookmarkNotices.notice == .noMessagesYet)
        #expect(harness.savedBookmarks.isEmpty)
    }

    @Test func allLettersInUseSaysWhy() async throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let bookmarks = MessageBookmarks.letters.enumerated().map { record, letter in bookmark(letter, at: record) }
        // Record 29, the newest, isn't among the 26 bookmarked.
        let harness = try Harness(conversation: files.conversation, bookmarks: bookmarks)
        defer { harness.close() }

        try await harness.toggle()

        #expect(harness.tab.bookmarkNotices.notice == .allLettersInUse)
        #expect(harness.savedBookmarks == bookmarks)
    }

    @Test func anUnreadableFileSaysSo() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let missing = Conversation.fixture(provider: .codex, sourceFile: directory.appendingPathComponent("gone.jsonl"))
        let harness = try Harness(conversation: missing)
        defer { harness.close() }

        try await harness.toggle()

        #expect(harness.tab.bookmarkNotices.notice == .couldNotRead)
        #expect(harness.savedBookmarks.isEmpty)
    }

    @Test func nextWithNoBookmarksSaysSoAndOpensNothing() throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let harness = try Harness(conversation: files.conversation)
        defer { harness.close() }

        harness.bookmarks.goToAdjacentBookmark(forward: true, from: harness.tab)

        #expect(harness.tab.bookmarkNotices.notice == .noBookmarks)
        // Had the press opened a window, this would bring it forward with the press's request waiting.
        let controller = try harness.openController()
        defer { controller.readingWindow.close() }
        #expect(controller.requests.navigationRevision == 0)
        #expect(controller.requests.pendingNavigation == nil)
    }

    /// A window opened by the press starts as from the conversation's end: Next at the first bookmark, Previous at the
    /// last, with that bookmark's page read first.
    @Test(arguments: [true, false])
    func nextOpensANewWindowAtTheFirstAndPreviousAtTheLast(forward: Bool) throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let bookmarks = [bookmark("a", at: 5), bookmark("b", at: 20)]
        let harness = try Harness(conversation: files.conversation, bookmarks: bookmarks)
        defer { harness.close() }

        harness.bookmarks.goToAdjacentBookmark(forward: forward, from: harness.tab)

        let controller = try harness.openController()
        defer { controller.readingWindow.close() }
        let expected = forward ? bookmarks[0] : bookmarks[1]
        #expect(controller.requests.pendingNavigation == .bookmark(expected))
        #expect(controller.readingPositionStore.position(for: files.conversation.id) == .entry(index: expected.entryID, offset: -6))
        #expect(harness.store.selectedTerminalID == harness.tab.id)
        #expect(harness.tab.bookmarkNotices.notice == nil)
    }

    /// An open window goes on from where its reader is; before its pages show, from where it was left, here the
    /// conversation's end, so Next asks for the first bookmark (RDR-50).
    @Test func nextInAnOpenWindowAsksItToGoOn() throws {
        let files = try TranscriptPagingFixture(count: 30)
        defer { files.remove() }
        let bookmarks = [bookmark("a", at: 5), bookmark("b", at: 20)]
        let harness = try Harness(conversation: files.conversation, bookmarks: bookmarks)
        defer { harness.close() }
        let controller = try harness.openController()
        defer { controller.readingWindow.close() }
        let revision = controller.requests.navigationRevision

        harness.bookmarks.goToAdjacentBookmark(forward: true, from: harness.tab)

        #expect(try harness.openController() === controller)
        #expect(controller.requests.navigationRevision == revision + 1)
        #expect(controller.requests.pendingNavigation == .bookmark(bookmarks[0]))
        #expect(harness.store.selectedTerminalID == harness.tab.id)
    }

    /// A window showing its pages goes on at once from the message being read at its top, through its own reader, as ⌘'
    /// in the window does, rather than through a request (RDR-50). Messages of 4 lines, so 540 can come to the top.
    @Test func nextInADrawnWindowGoesOnFromTheMessageAtItsTop() async throws {
        let files = try TranscriptPagingFixture(count: 600, lineCount: 4)
        defer { files.remove() }
        let bookmarks = [bookmark("a", at: 100), bookmark("b", at: 540), bookmark("c", at: 570)]
        let harness = try Harness(conversation: files.conversation, bookmarks: bookmarks)
        defer { harness.close() }
        // Listed, as a session open in a tab is, so the window's reader keeps bookmarks.
        harness.store.replaceConversations(on: .thisMac, with: [files.conversation])
        let window = harness.readingWindows.open(
            files.conversation, store: harness.store,
            initialPosition: .entry(index: id(500), offset: -6))
        defer { window.close() }
        let controller = try #require(window.windowController as? SessionReadingWindowController)
        try await expectEventually { Self.showsAtTop(id(500), in: window) }
        try #require(TranscriptBookmarkTargetRegistry.shared.target(in: window) != nil, "the window's reader must be drawn")
        let revision = controller.requests.navigationRevision

        harness.bookmarks.goToAdjacentBookmark(forward: true, from: harness.tab)

        #expect(controller.requests.pendingNavigation == nil)
        #expect(controller.requests.navigationRevision == revision)
        try await expectEventually { Self.showsAtTop(id(540), in: window) }
        #expect(Self.showsAtTop(id(540), in: window))
        #expect(harness.store.selectedTerminalID == harness.tab.id)
    }

    /// Whether the window's reader has the entry's top 6 points below its own, where a jump puts it, with nothing left to
    /// restore.
    private static func showsAtTop(_ entryID: Int, in window: NSWindow) -> Bool {
        guard let contentView = window.contentView else { return false }
        contentView.layoutSubtreeIfNeeded()
        guard let controller = geometryView(in: contentView)?.controller, !controller.isRestoring,
            let scrollView = controller.scrollView, let frame = controller.entryFrameInClipView(at: entryID)
        else { return false }
        return abs(frame.minY - TranscriptScrollPositionController.readableBounds(of: scrollView.contentView).minY - 6) < 1
    }

    private static func geometryView(in view: NSView) -> TranscriptEntryGeometryView? {
        if let view = view as? TranscriptEntryGeometryView { return view }
        return view.subviews.lazy.compactMap(geometryView(in:)).first
    }
}
