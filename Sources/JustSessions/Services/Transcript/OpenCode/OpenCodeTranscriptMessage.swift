import Foundation

struct OpenCodeTranscriptMessage: Sendable, Equatable {
    enum Role: Sendable {
        case user
        case assistant
    }

    /// A message's data without its file diffs, which hold whole files and are never shown. Malformed data reads
    /// as NULL instead of failing the query.
    static let dataProjection = "CASE WHEN json_valid(data) THEN json_remove(data, '$.summary.diffs') END"

    let id: String
    let role: Role
    let timestamp: Date
    let isCompactionSummary: Bool
    let errorText: String?

    init?(id: String, createdAtMilliseconds: Int64, data: Data?) {
        guard let data, let object = ConversationMetadata.object(from: data) else { return nil }
        switch object["role"] as? String {
        case "user": role = .user
        case "assistant": role = .assistant
        default: return nil
        }
        self.id = id
        timestamp = Date(timeIntervalSince1970: Double(createdAtMilliseconds) / 1_000)
        // A user message keeps a summary object; only a compaction's reply has `summary: true`.
        isCompactionSummary = role == .assistant && object["summary"] as? Bool == true
        errorText = Self.errorText(from: object["error"] as? [String: Any])
    }

    private static func errorText(from error: [String: Any]?) -> String? {
        guard let error, let name = error["name"] as? String, name != "MessageAbortedError" else { return nil }
        let message = (error["data"] as? [String: Any])?["message"] as? String
        return message.flatMap { $0.contains { !$0.isWhitespace } ? $0 : nil } ?? name
    }
}
