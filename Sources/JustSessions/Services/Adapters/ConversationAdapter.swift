import Foundation

protocol ConversationAdapter: Sendable {
    var provider: ConversationProvider { get }
    func discover() throws -> [Conversation]
    func arguments(for conversation: Conversation, action: ConversationAction) -> [String]
    func delete(_ conversation: Conversation) throws
}

enum ConversationAction: Sendable {
    case new
    case resume
    case branch

    /// New and Branch run a session of their own, whose id the app learns once the CLI writes it.
    var startsNewSession: Bool { self != .resume }
}

enum ConversationMetadata {
    /// Title of a session whose first prompt is not known yet.
    static let untitledConversationTitle = "Untitled conversation"

    static func date(_ value: Any?) -> Date? {
        guard let text = value as? String else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    static func object(from line: Data) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: line) as? [String: Any]
    }

    static func firstLine(of file: URL, maxBytes: Int = 65_536) -> [String: Any]? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes),
              let newline = data.firstIndex(of: 10) else { return nil }
        return object(from: Data(data[..<newline]))
    }

    static func fileModificationDate(_ file: URL) -> Date {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    static func isValidSessionID(_ value: String) -> Bool {
        UUID(uuidString: value) != nil
    }

    static func cleanTitle(_ rawTitle: String?, fallback: String) -> String {
        guard let rawTitle else { return fallback }
        let firstLine = rawTitle.components(separatedBy: .newlines).first ?? ""
        let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("<") { return fallback }
        return String(trimmed.prefix(120))
    }
}
