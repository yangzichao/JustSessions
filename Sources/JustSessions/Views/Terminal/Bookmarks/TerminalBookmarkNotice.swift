import Observation

/// What a bookmark command in a tab did, or why it did nothing (TRM-74). The terminal shows no letters, so each press says.
enum TerminalBookmarkNotice: Equatable {
    case added(MessageBookmark, assistantName: String)
    case removed(MessageBookmark, assistantName: String)
    case plainTerminal, notLinkedYet, noMessagesYet, allLettersInUse, noBookmarks, couldNotRead, findingLatestMessage

    /// "Finding…" stays until the press's result replaces it.
    var hidesByItself: Bool { self != .findingLatestMessage }

    func text(language: AppInterfaceLanguage?) -> String {
        func speaker(_ bookmark: MessageBookmark, _ assistantName: String) -> String {
            bookmark.kind == .user ? AppLocalization.string("You", language: language) : assistantName
        }
        switch self {
        case .added(let bookmark, let name):
            return AppLocalization.string(
                "Bookmark \(bookmark.letter) added · \(speaker(bookmark, name)): \(bookmark.menuSnippet)", language: language)
        case .removed(let bookmark, let name):
            return AppLocalization.string(
                "Bookmark \(bookmark.letter) removed · \(speaker(bookmark, name)): \(bookmark.menuTitle)", language: language)
        case .plainTerminal: return AppLocalization.string("A plain terminal has no conversation to bookmark.", language: language)
        case .notLinkedYet:
            return AppLocalization.string("This tab isn't linked to its session yet. Bookmarks work once it is.", language: language)
        case .noMessagesYet: return AppLocalization.string("No messages in this session yet.", language: language)
        case .allLettersInUse:
            return AppLocalization.string("All 26 letters are in use. Remove a bookmark to add another.", language: language)
        case .noBookmarks:
            return AppLocalization.string("No bookmarks in this session. Press ⌘D to bookmark its latest message.", language: language)
        case .couldNotRead: return AppLocalization.string("Could not read this session", language: language)
        case .findingLatestMessage: return AppLocalization.string("Finding the latest message…", language: language)
        }
    }
}

/// A tab's bookmark notice and the order of its ⌘D presses; on the tab as its find state is, so both follow it to
/// another window. The card reads `notice` in its own body only.
@MainActor
@Observable
final class TerminalBookmarkNoticeState {
    private(set) var notice: TerminalBookmarkNotice?
    /// Edit Bookmark… in this tab (TRM-74) or from its map (TAB-10); `TerminalWorkspaceView` presents it.
    @ObservationIgnored let editor = MessageBookmarkEditorRequests()
    @ObservationIgnored private var hidingTask: Task<Void, Never>?
    @ObservationIgnored private var lastCommand: Task<Void, Never>?

    /// Runs after every command enqueued before it, so two quick ⌘Ds add, then remove.
    @discardableResult
    func enqueue(_ command: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let previous = lastCommand
        let task = Task { @MainActor in
            await previous?.value
            await command()
        }
        lastCommand = task
        return task
    }

    /// As `TranscriptBookmarkState.show`: a notice goes after `TranscriptBookmarkState.hintDuration`, and VoiceOver reads it.
    func show(_ notice: TerminalBookmarkNotice) {
        self.notice = notice
        hidingTask?.cancel()
        hidingTask = nil
        if notice.hidesByItself {
            hidingTask = Task { [weak self] in
                try? await Task.sleep(for: TranscriptBookmarkState.hintDuration)
                guard !Task.isCancelled, self?.notice == notice else { return }
                self?.notice = nil
            }
        }
        TranscriptBookmarkState.announce(notice.text(language: nil))
    }

    func dismiss() {
        hidingTask?.cancel()
        hidingTask = nil
        if notice != nil { notice = nil }
    }
}
