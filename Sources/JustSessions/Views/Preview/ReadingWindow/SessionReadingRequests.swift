import Observation

enum SessionReadingNavigation: Equatable, Sendable {
    case adjacentBookmark(forward: Bool)
    case bookmark(MessageBookmark)
    case entry(Int)

    var entryID: Int? {
        switch self {
        case .adjacentBookmark: nil
        case .bookmark(let bookmark): bookmark.entryID
        case .entry(let entryID): entryID
        }
    }

    func forNewWindow(bookmarks: [MessageBookmark]) -> SessionReadingNavigation? {
        guard case .adjacentBookmark(let forward) = self else { return self }
        return (forward ? bookmarks.first : bookmarks.last).map(SessionReadingNavigation.bookmark)
    }
}

@MainActor
@Observable
final class SessionReadingRequests {
    private(set) var findRevision = 0
    private(set) var navigationRevision = 0
    @ObservationIgnored private(set) var pendingNavigation: SessionReadingNavigation?

    func requestFind() {
        findRevision += 1
    }

    func request(_ navigation: SessionReadingNavigation) {
        pendingNavigation = navigation
        navigationRevision += 1
    }

    func requestAdjacentBookmark(forward: Bool, in bookmarks: [MessageBookmark], from recorded: TranscriptReadingPosition?) {
        let anchor = pendingNavigation?.entryID ?? recorded?.entryIndex
        if let next = forward
            ? MessageBookmarkNavigation.bookmark(after: anchor, in: bookmarks)
            : MessageBookmarkNavigation.bookmark(before: anchor, in: bookmarks)
        {
            request(.bookmark(next))
        } else {
            request(.adjacentBookmark(forward: forward))
        }
    }

    func takeNavigation() -> SessionReadingNavigation? {
        defer { pendingNavigation = nil }
        return pendingNavigation
    }

    func discardNavigation() {
        pendingNavigation = nil
    }
}
