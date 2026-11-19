import Foundation

/// Each session's bookmarks, keyed by `Conversation.id`, each list in conversation order with one bookmark per letter
/// and per message.
struct MessageBookmarks: Equatable {
    static let userDefaultsKey = "messageBookmarks"
    static let letters = "abcdefghijklmnopqrstuvwxyz".map(String.init)

    private(set) var bookmarksByConversationID: [String: [MessageBookmark]]

    init(bookmarksByConversationID: [String: [MessageBookmark]] = [:]) {
        self.bookmarksByConversationID = bookmarksByConversationID.compactMapValues(Self.normalized)
    }

    static func load(from userDefaults: UserDefaults) -> MessageBookmarks {
        guard let data = userDefaults.data(forKey: userDefaultsKey),
            let saved = try? JSONDecoder().decode([String: [MessageBookmark]].self, from: data)
        else { return MessageBookmarks() }
        return MessageBookmarks(bookmarksByConversationID: saved)
    }

    func save(to userDefaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(bookmarksByConversationID) else { return }
        userDefaults.set(data, forKey: Self.userDefaultsKey)
    }

    func bookmarks(forConversationID conversationID: String) -> [MessageBookmark] {
        bookmarksByConversationID[conversationID] ?? []
    }

    /// Removes the message's bookmark, or adds one with the lowest free letter.
    mutating func toggle(entryID: Int, kind: MessageBookmark.Kind, snippet: String, conversationID: String) -> MessageBookmarkToggle {
        var bookmarks = bookmarks(forConversationID: conversationID)
        if let index = bookmarks.firstIndex(where: { $0.entryID == entryID }) {
            let removed = bookmarks.remove(at: index)
            set(bookmarks, forConversationID: conversationID)
            return .removed(removed)
        }
        guard let letter = Self.letters.first(where: { letter in !bookmarks.contains { $0.letter == letter } }) else {
            return .allLettersInUse
        }
        let added = MessageBookmark(letter: letter, entryID: entryID, kind: kind, snippet: snippet)
        set(bookmarks + [added], forConversationID: conversationID)
        return .added(added)
    }

    /// The message's bookmark, adding one with the lowest free letter when it has none; never removes one (⇧⌘D).
    mutating func ensure(entryID: Int, kind: MessageBookmark.Kind, snippet: String, conversationID: String) -> MessageBookmarkEnsuring {
        if let existing = bookmarks(forConversationID: conversationID).first(where: { $0.entryID == entryID }) {
            return .existing(existing)
        }
        switch toggle(entryID: entryID, kind: kind, snippet: snippet, conversationID: conversationID) {
        case .added(let added): return .added(added)
        case .removed, .allLettersInUse: return .allLettersInUse  // .removed is not reached: the message had none
        }
    }

    /// Sets the label and tags of the bookmark with this letter on this message, kept to `MessageBookmarkDetails`' rules.
    /// Nil, changing nothing, when another window removed it meanwhile.
    @discardableResult
    mutating func setDetails(of bookmark: MessageBookmark, label: String?, tags: [String], conversationID: String) -> MessageBookmark? {
        var bookmarks = bookmarks(forConversationID: conversationID)
        guard let index = bookmarks.firstIndex(where: { $0.letter == bookmark.letter && $0.entryID == bookmark.entryID }) else {
            return nil
        }
        bookmarks[index].label = label.flatMap(MessageBookmarkDetails.label(from:))
        bookmarks[index].tags = MessageBookmarkDetails.tags(from: tags)
        set(bookmarks, forConversationID: conversationID)
        return bookmarks[index]
    }

    /// Every tag in use, in any session, the most used first, then by name; each once whatever its case.
    var allTags: [String] {
        var counts: [String: (tag: String, count: Int)] = [:]
        for bookmark in bookmarksByConversationID.values.joined() {
            for tag in bookmark.tags {
                let key = MessageBookmarkDetails.searchKey(tag)
                counts[key] = (counts[key]?.tag ?? tag, (counts[key]?.count ?? 0) + 1)
            }
        }
        return counts.values.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.tag.localizedStandardCompare($1.tag) == .orderedAscending
        }.map(\.tag)
    }

    /// Each session's bookmarks that `query` finds, in conversation order; sessions with none are left out.
    func matches(for query: MessageBookmarkQuery, includingSnippets: Bool) -> [String: [MessageBookmark]] {
        bookmarksByConversationID.compactMapValues { bookmarks in
            let found = bookmarks.filter { query.matches($0, includingSnippet: includingSnippets) }
            return found.isEmpty ? nil : found
        }
    }

    /// Only the bookmark with this letter on this message, never one that took the letter since.
    mutating func remove(_ bookmark: MessageBookmark, conversationID: String) {
        set(
            bookmarks(forConversationID: conversationID).filter { $0.letter != bookmark.letter || $0.entryID != bookmark.entryID },
            forConversationID: conversationID)
    }

    mutating func removeAll(forConversationIDs conversationIDs: some Sequence<String>) {
        for conversationID in conversationIDs { bookmarksByConversationID[conversationID] = nil }
    }

    /// After a jump found the message at another part of its record, or with more of its text. If another bookmark
    /// already marks that message, the moved one goes. A moved bookmark keeps its label and tags.
    mutating func update(_ bookmark: MessageBookmark, entryID: Int, snippet: String, conversationID: String) {
        var bookmarks = bookmarks(forConversationID: conversationID)
        guard let index = bookmarks.firstIndex(where: { $0.letter == bookmark.letter && $0.entryID == bookmark.entryID }) else { return }
        if entryID != bookmark.entryID, bookmarks.contains(where: { $0.entryID == entryID }) {
            bookmarks.remove(at: index)
        } else {
            bookmarks[index].entryID = entryID
            bookmarks[index].snippet = snippet
        }
        set(bookmarks, forConversationID: conversationID)
    }

    private mutating func set(_ bookmarks: [MessageBookmark], forConversationID conversationID: String) {
        bookmarksByConversationID[conversationID] = Self.normalized(bookmarks)
    }

    /// Sorted by entry ID; only letters a–z; one bookmark per letter and per message; nil, dropping the key, when empty.
    private static func normalized(_ bookmarks: [MessageBookmark]) -> [MessageBookmark]? {
        var usedLetters = Set<String>()
        var markedEntryIDs = Set<Int>()
        var kept: [MessageBookmark] = []
        for bookmark in bookmarks.sorted(by: { ($0.entryID, $0.letter) < ($1.entryID, $1.letter) })
        where letters.contains(bookmark.letter) && !usedLetters.contains(bookmark.letter) && !markedEntryIDs.contains(bookmark.entryID) {
            usedLetters.insert(bookmark.letter)
            markedEntryIDs.insert(bookmark.entryID)
            kept.append(bookmark)
        }
        return kept.isEmpty ? nil : kept
    }
}
