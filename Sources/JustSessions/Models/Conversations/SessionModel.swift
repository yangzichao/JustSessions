import Foundation

/// The model a session's CLI used last, as the CLI records it, such as `claude-opus-4-8` or `gpt-5.5`, with the
/// reasoning effort when the CLI records one. Shown as recorded: a table of friendlier names would go stale with every
/// new model.
struct SessionModel: Sendable, Codable, Equatable, Hashable {
    let id: String
    let effort: String?

    /// Nil for no model, and for Claude Code's `<synthetic>`, which marks a message no model wrote.
    init?(id: String?, effort: String? = nil) {
        guard let id = id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty, id != "<synthetic>" else {
            return nil
        }
        self.id = id
        let effort = effort?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.effort = effort?.isEmpty == false ? effort : nil
    }

    /// Such as `gpt-5.5 · medium`.
    var label: String {
        [id, effort].compactMap { $0 }.joined(separator: " · ")
    }

    /// Shorter, for a sidebar row: Claude's `claude-` prefix and a trailing date left out, so
    /// `claude-haiku-4-5-20251001` reads `haiku-4-5`. Any other id is kept as it is.
    var shortName: String {
        var name = id
        if name.hasPrefix("claude-"), name.count > "claude-".count { name.removeFirst("claude-".count) }
        if let dash = name.lastIndex(of: "-"), name[name.index(after: dash)...].count == 8,
            name[name.index(after: dash)...].allSatisfy(\.isNumber), dash > name.startIndex
        {
            name = String(name[..<dash])
        }
        return name
    }
}
