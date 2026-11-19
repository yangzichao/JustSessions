import Foundation

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

    var label: String {
        [id, effort].compactMap { $0 }.joined(separator: " · ")
    }

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
