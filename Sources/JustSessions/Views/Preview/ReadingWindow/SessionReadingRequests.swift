import Observation

/// Where a reading window is asked to go from a tab or its conversation map (RDR-45, RDR-50).
enum SessionReadingNavigation: Equatable, Sendable {
    /// ⌘' or ⇧⌘' in a tab: on from where the reader is.
    case adjacentBookmark(forward: Bool)
    /// A bookmark chosen on the map, with the reader's missing-message handling.
    case bookmark(MessageBookmark)
    /// A message (or image) clicked on the map, by its paged entry ID.
    case entry(Int)

    var entryID: Int? {
        switch self {
        case .adjacentBookmark: nil
        case .bookmark(let bookmark): bookmark.entryID
        case .entry(let entryID): entryID
        }
    }

    /// A new window has no origin: as from the conversation's end, Next is the first bookmark and Previous the last
    /// (MessageBookmarkNavigation.bookmark(after:in:) with no origin), so it opens at that bookmark's page instead of
    /// loading the latest first.
    func forNewWindow(bookmarks: [MessageBookmark]) -> SessionReadingNavigation? {
        guard case .adjacentBookmark(let forward) = self else { return self }
        return (forward ? bookmarks.first : bookmarks.last).map(SessionReadingNavigation.bookmark)
    }
}

/// Asks a reading window's reader to open Find (⌘F in a linked tab, see `TerminalFindTarget`) or to go somewhere, once.
@MainActor
@Observable
final class SessionReadingRequests {
    /// Goes up with each Find request; 0 until the first.
    private(set) var findRevision = 0
    /// Goes up with each navigation request, which views observe; the navigation itself is taken once.
    private(set) var navigationRevision = 0
    @ObservationIgnored private(set) var pendingNavigation: SessionReadingNavigation?

    func requestFind() {
        findRevision += 1
    }

    /// A newer request replaces one not yet taken.
    func request(_ navigation: SessionReadingNavigation) {
        pendingNavigation = navigation
        navigationRevision += 1
    }

    /// Next or Previous while the window shows no pages: on from what a waiting request asked for, else from where the
    /// window was left (`recorded`; the bottom counts as the conversation's end), so presses before the reader loads add up
    /// and none is resolved before the reader knows where it is (RDR-49, RDR-50).
    func requestAdjacentBookmark(forward: Bool, in bookmarks: [MessageBookmark], from recorded: TranscriptReadingPosition?) {
        let anchor = pendingNavigation?.entryID ?? recorded?.entryIndex
        if let next = forward
            ? MessageBookmarkNavigation.bookmark(after: anchor, in: bookmarks)
            : MessageBookmarkNavigation.bookmark(before: anchor, in: bookmarks)
        {
            request(.bookmark(next))
        } else {
            request(.adjacentBookmark(forward: forward))  // no bookmarks: the reader says so
        }
    }

    /// Once: a reader rebuilt later finds nothing.
    func takeNavigation() -> SessionReadingNavigation? {
        defer { pendingNavigation = nil }
        return pendingNavigation
    }

    func discardNavigation() {
        pendingNavigation = nil
    }
}
