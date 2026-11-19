import Foundation

/// What All Bookmarks lists (RDR-52): each listed session's bookmarks that the search and the chosen tags keep, the most
/// recently active session first, each session's in conversation order.
struct AllBookmarksList: Equatable {
    struct Section: Identifiable, Equatable {
        let conversation: Conversation
        let bookmarks: [MessageBookmark]
        var id: String { conversation.id }
    }

    let sections: [Section]
    /// Bookmarks kept for sessions no host lists now, as after removing an SSH host (RDR-29); they show again once listed.
    let unlistedBookmarkCount: Int

    var bookmarkCount: Int { sections.reduce(0) { $0 + $1.bookmarks.count } }

    /// - Parameters:
    ///   - query: matches a bookmark's label, tags, or message, or its session's title; nil keeps every bookmark.
    ///   - requiredTags: a bookmark must have every one, ignoring case and accents.
    ///   - conversation: the listed session with an ID, or nil.
    ///   - title: the session's title as the sidebar shows it.
    init(
        bookmarks: MessageBookmarks, query: MessageBookmarkQuery?, requiredTags: Set<String>,
        conversation: (String) -> Conversation?, title: (Conversation) -> String
    ) {
        let requiredKeys = Set(requiredTags.map(MessageBookmarkDetails.searchKey))
        var sections: [Section] = []
        var unlisted = 0
        for (conversationID, sessionBookmarks) in bookmarks.bookmarksByConversationID {
            guard let listed = conversation(conversationID) else {
                unlisted += sessionBookmarks.count
                continue
            }
            let titleMatches = query?.matches(sessionTitle: title(listed)) == true
            let kept = sessionBookmarks.filter { bookmark in
                let tagKeys = Set(bookmark.tags.map(MessageBookmarkDetails.searchKey))
                return requiredKeys.isSubset(of: tagKeys)
                    && (query == nil || titleMatches || query?.matches(bookmark, includingSnippet: true) == true)
            }
            if !kept.isEmpty { sections.append(Section(conversation: listed, bookmarks: kept)) }
        }
        self.sections = sections.sorted {
            $0.conversation.updatedAt != $1.conversation.updatedAt
                ? $0.conversation.updatedAt > $1.conversation.updatedAt : $0.conversation.id < $1.conversation.id
        }
        unlistedBookmarkCount = unlisted
    }
}
