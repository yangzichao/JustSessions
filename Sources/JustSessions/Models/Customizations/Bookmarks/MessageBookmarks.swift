import Foundation

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

    mutating func toggle(entryID: Int, kind: MessageBookmark.Kind, snippet: String, conversationID: String) -> MessageBookmarkToggle {
        var bookmarks = bookmarks(forConversationID: conversationID)
        if let index = bookmarks.firstIndex(where: { $0.entryID == entryID }) {
            let removed = bookmarks.remove(at: index)
            set(bookmarks, forConversationID: conversationID)
            return .removed(removed)
        }
        guard let added = addWithLowestFreeLetter(entryID: entryID, kind: kind, snippet: snippet, conversationID: conversationID)
        else { return .allLettersInUse }
        return .added(added)
    }

    mutating func ensure(entryID: Int, kind: MessageBookmark.Kind, snippet: String, conversationID: String) -> MessageBookmarkEnsuring {
        if let existing = bookmarks(forConversationID: conversationID).first(where: { $0.entryID == entryID }) {
            return .existing(existing)
        }
        guard let added = addWithLowestFreeLetter(entryID: entryID, kind: kind, snippet: snippet, conversationID: conversationID)
        else { return .allLettersInUse }
        return .added(added)
    }

    private mutating func addWithLowestFreeLetter(
        entryID: Int, kind: MessageBookmark.Kind, snippet: String, conversationID: String
    ) -> MessageBookmark? {
        let bookmarks = bookmarks(forConversationID: conversationID)
        guard let letter = Self.letters.first(where: { letter in !bookmarks.contains { $0.letter == letter } }) else { return nil }
        let added = MessageBookmark(letter: letter, entryID: entryID, kind: kind, snippet: snippet)
        set(bookmarks + [added], forConversationID: conversationID)
        return added
    }

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

    func matches(for query: MessageBookmarkQuery, includingSnippets: Bool) -> [String: [MessageBookmark]] {
        bookmarksByConversationID.compactMapValues { bookmarks in
            let found = bookmarks.filter { query.matches($0, includingSnippet: includingSnippets) }
            return found.isEmpty ? nil : found
        }
    }

    mutating func remove(_ bookmark: MessageBookmark, conversationID: String) {
        set(
            bookmarks(forConversationID: conversationID).filter { $0.letter != bookmark.letter || $0.entryID != bookmark.entryID },
            forConversationID: conversationID)
    }

    mutating func removeAll(forConversationIDs conversationIDs: some Sequence<String>) {
        for conversationID in conversationIDs { bookmarksByConversationID[conversationID] = nil }
    }

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
