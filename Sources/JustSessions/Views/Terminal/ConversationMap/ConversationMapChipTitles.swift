import AppKit

@MainActor
enum ConversationMapChipTitles {
    private struct Key: Hashable {
        let label: String
        let fontSize: CGFloat
        let maximumWidth: CGFloat
    }

    private static let cacheLimit = 512
    private static var cache: [Key: ConversationMapLayout.ChipTitle] = [:]

    static func titles(
        for bookmarks: [MessageBookmark], side: CGFloat,
        factor: CGFloat = InterfaceScale.factor
    ) -> [String: ConversationMapLayout.ChipTitle] {
        var titles: [String: ConversationMapLayout.ChipTitle] = [:]
        for bookmark in bookmarks {
            guard let label = bookmark.label.map(Self.oneLine), !label.isEmpty else { continue }
            titles[bookmark.letter] = title(for: label, side: side, factor: factor)
        }
        return titles
    }

    static func title(for label: String, side: CGFloat, factor: CGFloat) -> ConversationMapLayout.ChipTitle {
        let key = Key(
            label: label, fontSize: ConversationMapMetrics.chipFontSize(at: factor),
            maximumWidth: ConversationMapMetrics.labelChipMaximumWidth(at: factor))
        if let title = cache[key] { return title }
        if cache.count >= cacheLimit { cache.removeAll(keepingCapacity: true) }
        let title = measure(key, padding: ConversationMapMetrics.chipPadding(at: factor), side: side)
        cache[key] = title
        return title
    }

    private static func measure(_ key: Key, padding: CGFloat, side: CGFloat) -> ConversationMapLayout.ChipTitle {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: key.fontSize, weight: .semibold)]
        func width(_ text: String) -> CGFloat { ((text as NSString).size(withAttributes: attributes).width + 2 * padding).rounded(.up) }
        let full = width(key.label)
        guard full > key.maximumWidth else { return .init(text: key.label, width: max(side, full)) }
        let characters = Array(key.label)
        var low = 0
        var high = characters.count
        while low < high {
            let middle = (low + high + 1) / 2
            if width(Self.cut(characters, at: middle)) <= key.maximumWidth { low = middle } else { high = middle - 1 }
        }
        let text = Self.cut(characters, at: low)
        return .init(text: text, width: min(key.maximumWidth, max(side, width(text))))
    }

    private static func cut(_ characters: [Character], at count: Int) -> String {
        String(characters.prefix(count)).trimmingCharacters(in: .whitespaces) + "…"
    }

    private static func oneLine(_ label: String) -> String {
        label.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }
}
