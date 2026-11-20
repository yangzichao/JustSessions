@MainActor
struct TerminalTabBookmarks {
    let store: ConversationStore
    var readingWindows = SessionReadingWindowManager.shared
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

    @discardableResult
    func toggleLatestMessage(in tab: TerminalSession) -> Task<Void, Never>? {
        actOnLatestMessage(in: tab) { message, conversation in
            let name = conversation.provider.rawValue
            switch store.toggleMessageBookmark(on: message, in: conversation) {
            case .added(let bookmark): tab.bookmarkNotices.show(.added(bookmark, assistantName: name))
            case .removed(let bookmark): tab.bookmarkNotices.show(.removed(bookmark, assistantName: name))
            case .allLettersInUse: tab.bookmarkNotices.show(.allLettersInUse)
            }
        }
    }

    @discardableResult
    func editLatestMessage(in tab: TerminalSession) -> Task<Void, Never>? {
        actOnLatestMessage(in: tab) { message, conversation in
            switch store.ensureMessageBookmark(on: message, in: conversation) {
            case .existing(let bookmark), .added(let bookmark):
                tab.bookmarkNotices.dismiss()
                tab.bookmarkNotices.editor.open(bookmark, in: conversation)
            case .allLettersInUse: tab.bookmarkNotices.show(.allLettersInUse)
            }
        }
    }

    private func actOnLatestMessage(
        in tab: TerminalSession,
        _ act: @escaping @MainActor (BookmarkableMessage, Conversation) -> Void
    ) -> Task<Void, Never>? {
        guard let conversation = linkedConversation(of: tab) else { return nil }
        return tab.bookmarkNotices.enqueue {
            let findingNoticeCancelledBeforeAnythingYieldsAfterTheRead = showFindingNoticeAfterADelayUnlessCancelled(in: tab)
            defer { findingNoticeCancelledBeforeAnythingYieldsAfterTheRead.cancel() }
            let message: BookmarkableMessage?
            do {
                message = try await tab.conversationOutline.latestMessage(of: conversation)
            } catch is CancellationError {
                tab.bookmarkNotices.dismiss()
                return
            } catch {
                tab.bookmarkNotices.show(.couldNotRead)
                return
            }
            guard let message else {
                tab.bookmarkNotices.show(.noMessagesYet)
                return
            }
            act(message, conversation)
        }
    }

    private func showFindingNoticeAfterADelayUnlessCancelled(in tab: TerminalSession) -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: Self.findingNoticeDelay)
            if !Task.isCancelled { tab.bookmarkNotices.show(.findingLatestMessage) }
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

    private func linkedConversation(of tab: TerminalSession) -> Conversation? {
        guard let conversation = tab.conversation else {
            tab.bookmarkNotices.show(tab.isPlainTerminal ? .plainTerminal : .notLinkedYet)
            return nil
        }
        return store.conversation(withID: conversation.id) ?? conversation
    }
}
