import Foundation

struct MessageBookmark: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case user, assistant

        init?(_ content: TranscriptEntry.Content) {
            switch content {
            case .userMessage: self = .user
            case .assistantMessage: self = .assistant
            default: return nil
            }
        }
    }

    let letter: String
    var entryID: Int
    let kind: Kind
    var snippet: String
    var label: String? = nil
    var tags: [String] = []

    var menuSnippet: String { snippet.count > 50 ? String(snippet.prefix(49)) + "…" : snippet }

    var menuTitle: String {
        guard let label else { return menuSnippet }
        return label.count > 50 ? String(label.prefix(49)) + "…" : label
    }
}

extension MessageBookmark {
    private enum CodingKeys: String, CodingKey {
        case letter, entryID, kind, snippet, label, tags
    }

    /// Bookmarks saved before labels and tags existed have neither. In an extension, so the memberwise initializer stays.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        letter = try container.decode(String.self, forKey: .letter)
        entryID = try container.decode(Int.self, forKey: .entryID)
        kind = try container.decode(Kind.self, forKey: .kind)
        snippet = try container.decode(String.self, forKey: .snippet)
        label = MessageBookmarkDetails.label(from: try container.decodeIfPresent(String.self, forKey: .label) ?? "")
        tags = MessageBookmarkDetails.tags(from: try container.decodeIfPresent([String].self, forKey: .tags) ?? [])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(letter, forKey: .letter)
        try container.encode(entryID, forKey: .entryID)
        try container.encode(kind, forKey: .kind)
        try container.encode(snippet, forKey: .snippet)
        try container.encodeIfPresent(label, forKey: .label)
        if !tags.isEmpty { try container.encode(tags, forKey: .tags) }
    }
}

enum MessageBookmarkToggle: Equatable {
    case added(MessageBookmark)
    case removed(MessageBookmark)
    case allLettersInUse
}

enum MessageBookmarkEnsuring: Equatable {
    case existing(MessageBookmark)
    case added(MessageBookmark)
    case allLettersInUse

    var bookmark: MessageBookmark? {
        switch self {
        case .existing(let bookmark), .added(let bookmark): bookmark
        case .allLettersInUse: nil
        }
    }
}

enum MessageBookmarkDetails {
    static let maximumLabelLength = 80
    static let maximumTagLength = 32
    static let maximumTagCount = 12

    static func label(from text: String) -> String? {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        return String(words.joined(separator: " ").prefix(maximumLabelLength))
    }

    static func tags(fromTyped text: String) -> [String] {
        tags(from: text.split { $0 == "," || $0 == "，" || $0.isWhitespace }.map(String.init))
    }

    static func tags(from candidates: [String]) -> [String] {
        var seen = Set<String>()
        var kept: [String] = []
        for candidate in candidates {
            let tag = String(
                candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                    .drop { $0 == "#" }
                    .split(whereSeparator: \.isWhitespace).joined(separator: "-")
                    .prefix(maximumTagLength))
            guard !tag.isEmpty, seen.insert(searchKey(tag)).inserted else { continue }
            kept.append(tag)
            if kept.count == maximumTagCount { break }
        }
        return kept
    }

    static func typedText(of tags: [String]) -> String {
        tags.map { "#" + $0 }.joined(separator: " ")
    }

    static func searchKey(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}

enum MessageBookmarkTagTyping {
    static let maximumSuggestionCount = 12

    static func suggestions(from allTags: [String], typed: String) -> [String] {
        let typedKeys = Set(MessageBookmarkDetails.tags(fromTyped: typed).map(MessageBookmarkDetails.searchKey))
        let partial = partialTag(in: typed).map(MessageBookmarkDetails.searchKey)
        return Array(
            allTags.filter { tag in
                let key = MessageBookmarkDetails.searchKey(tag)
                return !typedKeys.contains(key) && (partial.map { key.hasPrefix($0) } ?? true)
            }.prefix(maximumSuggestionCount))
    }

    static func partialTag(in typed: String) -> String? {
        guard let last = typed.last, !isSeparator(last) else { return nil }
        let word = typed.split(whereSeparator: isSeparator).last.map { String($0.drop { $0 == "#" }) }
        return word?.isEmpty == false ? word : nil
    }

    static func adding(_ tag: String, to typed: String) -> String {
        var text = typed
        let withoutHashes = String(text.reversed().drop { $0 == "#" }.reversed())
        if withoutHashes.count < text.count, withoutHashes.last.map(isSeparator) ?? true { text = withoutHashes }
        if partialTag(in: text) != nil, let range = text.range(of: "#?[^\\s,，#]*$", options: .regularExpression) {
            text.removeSubrange(range)
        } else if let last = text.last, !isSeparator(last) {
            text += " "
        }
        return text + "#" + tag + " "
    }

    private static func isSeparator(_ character: Character) -> Bool {
        character == "," || character == "，" || character.isWhitespace
    }
}
