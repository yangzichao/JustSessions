import Foundation

struct MessageBookmarkQuery: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case tagPrefix(String)
        case text(String)
    }

    let kind: Kind

    init?(_ typed: String) {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") {
            let tag = MessageBookmarkDetails.searchKey(String(trimmed.drop { $0 == "#" }))
            guard !tag.isEmpty else { return nil }
            kind = .tagPrefix(tag)
        } else {
            guard !trimmed.isEmpty else { return nil }
            kind = .text(MessageBookmarkDetails.searchKey(trimmed))
        }
    }

    func matches(_ bookmark: MessageBookmark, includingSnippet: Bool) -> Bool {
        switch kind {
        case .tagPrefix(let prefix):
            return bookmark.tags.contains { MessageBookmarkDetails.searchKey($0).hasPrefix(prefix) }
        case .text(let text):
            return bookmark.label.map { MessageBookmarkDetails.searchKey($0).contains(text) } == true
                || bookmark.tags.contains { MessageBookmarkDetails.searchKey($0).contains(text) }
                || (includingSnippet && MessageBookmarkDetails.searchKey(bookmark.snippet).contains(text))
        }
    }

    func matches(sessionTitle: String) -> Bool {
        guard case .text(let text) = kind else { return false }
        return MessageBookmarkDetails.searchKey(sessionTitle).contains(text)
    }
}
