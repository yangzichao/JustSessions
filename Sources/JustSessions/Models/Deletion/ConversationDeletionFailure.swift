import Foundation

/// A session that could not be deleted, with the reason its tool or host gave.
struct ConversationDeletionFailure: Sendable {
    let conversation: Conversation
    let reason: String
    /// The SSH host given up on, when that is why the session was not deleted.
    var unresponsiveHost: UnresponsiveSSHHost? = nil

    /// Lines under the heading of the message after deleting several sessions, so the alert fits on the screen
    /// however many sessions failed. When more are needed, the last one counts the sessions left out.
    static let maximumListedLines = 8
    /// Up to this many sessions that failed for a reason other than an unresponsive host get a line each; more
    /// are grouped by reason.
    static let maximumSessionsListedOneByOne = 5
    /// The reason shown after deleting one session keeps at most this many lines and characters; a host's
    /// output can be long.
    static let maximumOneSessionReasonLines = 6
    static let maximumOneSessionReasonLength = 300

    /// What is shown after deleting one session: the reason alone, since the user just picked the session.
    static func messageAfterDeletingOneSession(_ failures: [ConversationDeletionFailure]) -> String {
        failures.map { failure in
            let lines = failure.reason.split(separator: "\n", omittingEmptySubsequences: false)
            let keptLines = lines.prefix(maximumOneSessionReasonLines).joined(separator: "\n")
            let isCut = lines.count > maximumOneSessionReasonLines || keptLines.count > maximumOneSessionReasonLength
            return isCut ? keptLines.prefix(maximumOneSessionReasonLength - 1) + "…" : keptLines
        }.joined(separator: "\n")
    }

    /// What is shown after deleting several sessions: which ones failed, and why. Each host given up on takes one
    /// line; a handful of other failures name each session, and more are grouped by reason, the most common first.
    static func messageAfterDeletingSeveralSessions(_ failures: [ConversationDeletionFailure]) -> String {
        let hostLines = groupedByCount(failures.compactMap { failure in failure.unresponsiveHost.map { ($0, failure) } })
            .map { unresponsiveHost, hostFailures in
                ListedLine(
                    text: "\(shortened(unresponsiveHost.explanation, to: 80)), so \(sessionsPhrase(hostFailures.count)) on it "
                        + "\(hostFailures.count == 1 ? "was" : "were") not deleted.",
                    sessionCount: hostFailures.count
                )
            }
        let otherFailures = failures.filter { $0.unresponsiveHost == nil }
        let otherLines = otherFailures.count <= maximumSessionsListedOneByOne
            ? otherFailures.map { ListedLine(text: oneSessionLine($0), sessionCount: 1) }
            : groupedByCount(otherFailures.map { ($0.reason, $0) }).map { reason, reasonFailures in
                ListedLine(
                    text: reasonFailures.count == 1
                        ? oneSessionLine(reasonFailures[0])
                        : "\(namedSessions(reasonFailures.map(\.conversation))): \(shortened(reason, to: 80))",
                    sessionCount: reasonFailures.count
                )
            }

        var lines = (hostLines + otherLines).map(\.text)
        if lines.count > maximumListedLines {
            let leftOutCount = (hostLines + otherLines).dropFirst(maximumListedLines - 1).reduce(0) { $0 + $1.sessionCount }
            lines = Array(lines.prefix(maximumListedLines - 1))
                + ["\(leftOutCount.formatted()) more \(leftOutCount == 1 ? "session" : "sessions") could not be deleted."]
        }
        return (["Some sessions could not be deleted:"] + lines).joined(separator: "\n")
    }

    /// "Claude Code · Title: reason", shortened.
    private static func oneSessionLine(_ failure: ConversationDeletionFailure) -> String {
        "\(failure.conversation.provider.rawValue) · \(shortened(failure.conversation.suggestedTitle, to: 40)): "
            + shortened(failure.reason, to: 120)
    }

    private struct ListedLine {
        let text: String
        let sessionCount: Int
    }

    /// The failures grouped by key, the largest group first; equal groups keep the order they first appear in.
    private static func groupedByCount<Key: Hashable>(
        _ keyedFailures: [(Key, ConversationDeletionFailure)]
    ) -> [(key: Key, failures: [ConversationDeletionFailure])] {
        var keysInOrder: [Key] = []
        var failuresByKey: [Key: [ConversationDeletionFailure]] = [:]
        for (key, failure) in keyedFailures {
            if failuresByKey[key] == nil { keysInOrder.append(key) }
            failuresByKey[key, default: []].append(failure)
        }
        return keysInOrder.enumerated()
            .sorted { first, second in
                let firstCount = failuresByKey[first.element]?.count ?? 0
                let secondCount = failuresByKey[second.element]?.count ?? 0
                return firstCount != secondCount ? firstCount > secondCount : first.offset < second.offset
            }
            .map { (key: $0.element, failures: failuresByKey[$0.element] ?? []) }
    }

    private static func sessionsPhrase(_ count: Int) -> String {
        "\(count.formatted()) \(count == 1 ? "session" : "sessions")"
    }

    /// The count, then the first two titles: "2 sessions, “a” and “b”" or "15 sessions, including “a” and “b”".
    private static func namedSessions(_ conversations: [Conversation]) -> String {
        let titles = conversations.prefix(2).map { "“\(shortened($0.suggestedTitle, to: 24))”" }.joined(separator: " and ")
        return "\(sessionsPhrase(conversations.count)), \(conversations.count > 2 ? "including " : "")\(titles)"
    }

    /// One line of at most `limit` characters, ending in an ellipsis when cut.
    private static func shortened(_ text: String, to limit: Int) -> String {
        let singleLine = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return singleLine.count > limit ? singleLine.prefix(limit - 1) + "…" : singleLine
    }
}
