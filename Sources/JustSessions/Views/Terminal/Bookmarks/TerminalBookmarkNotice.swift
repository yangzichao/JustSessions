import Observation

enum TerminalBookmarkNotice: Equatable {
    case added(MessageBookmark, assistantName: String)
    case removed(MessageBookmark, assistantName: String)
    case plainTerminal, notLinkedYet, noMessagesYet, allLettersInUse, noBookmarks, couldNotRead, findingLatestMessage

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

@MainActor
@Observable
final class TerminalBookmarkNoticeState {
    private(set) var notice: TerminalBookmarkNotice?
    @ObservationIgnored let editor = MessageBookmarkEditorRequests()
    @ObservationIgnored private var hidingTask: Task<Void, Never>?
    @ObservationIgnored private var lastCommand: Task<Void, Never>?

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
