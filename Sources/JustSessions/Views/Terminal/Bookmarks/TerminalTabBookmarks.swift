/// ⌘D, ⇧⌘D, ⌘', and ⇧⌘' in a tab (TRM-74), through the Bookmarks menu. A tab has no loaded pages, so ⌘D reads the newest
/// message off the main thread; ⌘' hands the jump to the session's reading window, leaving the selected tab as ⌘F does
/// (WorkspaceDetailView.findInSelectedTab). The terminal shows no letters, so a notice over it says what happened.
@MainActor
struct TerminalTabBookmarks {
    let store: ConversationStore
    var readingWindows = SessionReadingWindowManager.shared
    /// A cold read, as a large Pi file's branch scan (PERF-67), says it is finding the message after this long.
    nonisolated static let findingNoticeDelay: Duration = .milliseconds(400)

    var commandTarget: TranscriptBookmarkCommandTarget {
        TranscriptBookmarkCommandTarget(
            toggleBookmark: { if let tab = store.selectedTerminal { toggleLatestMessage(in: tab) } },
            goToAdjacentBookmark: { forward in
                if let tab = store.selectedTerminal { goToAdjacentBookmark(forward: forward, from: tab) }
            },
            contextMenuItems: { _ in [] },
            editBookmark: { if let tab = store.selectedTerminal { editLatestMessage(in: tab) } })
    }

    /// Bookmarks the conversation it read, even if the tab relinks meanwhile; the notice names the message.
    @discardableResult
    func toggleLatestMessage(in tab: TerminalSession) -> Task<Void, Never>? {
        actOnLatestMessage(in: tab) { entry, conversation in
            let name = conversation.provider.rawValue  // as TranscriptBookmarkMenu labels replies
            switch store.toggleMessageBookmark(on: entry, in: conversation) {
            case .added(let bookmark): tab.bookmarkNotices.show(.added(bookmark, assistantName: name))
            case .removed(let bookmark): tab.bookmarkNotices.show(.removed(bookmark, assistantName: name))
            case .allLettersInUse: tab.bookmarkNotices.show(.allLettersInUse)
            case nil: tab.bookmarkNotices.show(.noMessagesYet)  // not reached: only messages are returned
            }
        }
    }

    /// Edit Bookmark… (⇧⌘D): the newest message's bookmark, added first when it has none, read as ⌘D reads it (RDR-51).
    @discardableResult
    func editLatestMessage(in tab: TerminalSession) -> Task<Void, Never>? {
        actOnLatestMessage(in: tab) { entry, conversation in
            switch store.ensureMessageBookmark(on: entry, in: conversation) {
            case .existing(let bookmark), .added(let bookmark):
                tab.bookmarkNotices.dismiss()
                tab.bookmarkNotices.editor.open(bookmark, in: conversation)
            case .allLettersInUse: tab.bookmarkNotices.show(.allLettersInUse)
            case nil: tab.bookmarkNotices.show(.noMessagesYet)  // not reached: only messages are returned
            }
        }
    }

    /// Reads the newest of your messages or the CLI's replies off the main thread, after every press before it, and acts on
    /// it in the conversation it read; a notice says it is finding one after a while, or why there is none.
    private func actOnLatestMessage(
        in tab: TerminalSession,
        _ act: @escaping @MainActor (TranscriptEntry, Conversation) -> Void
    ) -> Task<Void, Never>? {
        guard let conversation = linkedConversation(of: tab) else { return nil }
        return tab.bookmarkNotices.enqueue {
            // Cannot fire after the result: nothing yields between showing it and the deferred cancel.
            let finding = Task { @MainActor in
                try? await Task.sleep(for: Self.findingNoticeDelay)
                if !Task.isCancelled { tab.bookmarkNotices.show(.findingLatestMessage) }
            }
            defer { finding.cancel() }
            let entry: TranscriptEntry?
            do {
                entry = try await tab.conversationOutline.latestMessage(of: conversation)
            } catch is CancellationError {
                tab.bookmarkNotices.dismiss()
                return
            } catch {
                tab.bookmarkNotices.show(.couldNotRead)
                return
            }
            guard let entry else {
                tab.bookmarkNotices.show(.noMessagesYet)
                return
            }
            act(entry, conversation)
        }
    }

    func goToAdjacentBookmark(forward: Bool, from tab: TerminalSession) {
        guard let conversation = linkedConversation(of: tab) else { return }
        guard !store.messageBookmarks.bookmarks(forConversationID: conversation.id).isEmpty else {
            tab.bookmarkNotices.show(.noBookmarks)
            return
        }
        readingWindows.open(conversation, store: store, navigation: .adjacentBookmark(forward: forward))
    }

    /// The tab's session as its window lists it now (ConversationStore+Lookups.swift), or a notice saying why none: the
    /// test `TerminalFindTarget` uses.
    private func linkedConversation(of tab: TerminalSession) -> Conversation? {
        guard let conversation = tab.conversation else {
            tab.bookmarkNotices.show(tab.isPlainTerminal ? .plainTerminal : .notLinkedYet)
            return nil
        }
        return store.conversation(withID: conversation.id) ?? conversation
    }
}
