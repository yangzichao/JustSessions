import Foundation

struct SessionDeletionReport: Sendable {
    let requestedCount: Int
    let deletedCount: Int
    let failures: [ConversationDeletionFailure]
    var wasCanceled = false

    static let maximumListedCauses = 4
    static let maximumMessageLength = 1_500
    static let maximumSessionsListedOneByOne = 3
    static let maximumOneSessionReasonLines = 6
    static let maximumOneSessionReasonLength = 300
    static let maximumTitleLengthInAlertTitle = 40

    static func oneSessionTitle(_ sessionTitle: String) -> String {
        "Couldn't delete “\(shortened(sessionTitle, to: maximumTitleLengthInAlertTitle))”"
    }

    func alert(titleOf: (Conversation) -> String) -> StoreAlert? {
        guard !failures.isEmpty else { return nil }
        if requestedCount == 1, let failure = failures.first {
            let sessionTitle = titleOf(failure.conversation)
            return StoreAlert(
                title: failure.isStillListed
                    ? Self.oneSessionTitle(sessionTitle)
                    : "“\(Self.shortened(sessionTitle, to: Self.maximumTitleLengthInAlertTitle))” was deleted with an error",
                message: Self.boundedOneSessionReason(failure.reason),
                retryConversationIDs: retryConversationIDs
            )
        }
        return StoreAlert(
            title: notDeletedCount > 0
                ? "\(Self.sessionsPhrase(notDeletedCount)) \(notDeletedCount == 1 ? "wasn't" : "weren't") deleted"
                : "Deletion finished with errors",
            message: messageAfterDeletingSeveralSessions(titleOf: titleOf),
            retryConversationIDs: retryConversationIDs
        )
    }

    var retryConversationIDs: Set<String> {
        Set(retriableFailures.map(\.conversation.id))
    }

    private var retriableFailures: [ConversationDeletionFailure] {
        failures.filter { $0.isStillListed && $0.unresponsiveHost?.isLikelyTemporary == true }
    }

    private var notDeletedCount: Int {
        failures.filter(\.isStillListed).count
    }

    func messageAfterDeletingSeveralSessions(titleOf: (Conversation) -> String) -> String {
        let hostCauses = Self.groupedByCount(
            failures.compactMap { failure in
                failure.unresponsiveHost.map { ($0.host, failure) }
            }
        ).map { host, hostFailures in
            let unresponsiveHost = hostFailures.first?.unresponsiveHost
            let explanation = Self.sentence(unresponsiveHost?.explanation ?? "")
            let notDeletedCount = hostFailures.filter(\.isStillListed).count
            let outcome: String
            if case .didNotRespondInTime? = unresponsiveHost {
                outcome = "may not have been deleted"
            } else {
                outcome = notDeletedCount == 1 ? "wasn't deleted" : "weren't deleted"
            }
            return Cause(
                text: explanation + " \(Self.sessionsPhrase(notDeletedCount)) on \(Self.shortened(host, to: 60)) \(outcome).",
                explanation: explanation,
                sessionCount: hostFailures.count,
                notDeletedCount: notDeletedCount
            )
        }
        let otherFailures = failures.filter { $0.unresponsiveHost == nil }
        func oneSessionCause(_ failure: ConversationDeletionFailure) -> Cause {
            Cause(
                text: "\(failure.conversation.provider.rawValue) · \(Self.shortened(titleOf(failure.conversation), to: 40)): "
                    + Self.sentence(Self.shortened(failure.reason, to: 160)),
                sessionCount: 1
            )
        }
        let otherCauses =
            otherFailures.count <= Self.maximumSessionsListedOneByOne
            ? otherFailures.map(oneSessionCause)
            : Self.groupedByCount(otherFailures.map { ($0.reason, $0) }).map { reason, reasonFailures in
                reasonFailures.count == 1
                    ? oneSessionCause(reasonFailures[0])
                    : Cause(
                        text: "\(Self.namedSessions(reasonFailures.map(\.conversation), titleOf: titleOf)): "
                            + Self.sentence(Self.shortened(reason, to: 100)),
                        sessionCount: reasonFailures.count
                    )
            }
        let causes = hostCauses + otherCauses
        let nextStep = tryAgainStep

        var paragraphs: [String]
        if causes.count == 1, let onlyCause = causes.first, let explanation = onlyCause.explanation,
            onlyCause.notDeletedCount == requestedCount - deletedCount
        {
            paragraphs = [summary(telling: explanation)]
        } else {
            let summary = summary(telling: nil)
            let reservedLength = summary.count + (nextStep.map { $0.count + 2 } ?? 0)
            paragraphs = [summary] + Self.boundedCauses(causes, besides: reservedLength)
        }
        if let nextStep { paragraphs.append(nextStep) }
        return paragraphs.joined(separator: "\n\n")
    }

    private func summary(telling explanation: String?) -> String {
        let stillListedCount = requestedCount - deletedCount
        let whenStopped = wasCanceled ? " before you canceled" : ""
        let because = explanation.map { " " + $0 } ?? ""
        guard deletedCount > 0 else {
            return "None of the \(requestedCount.formatted()) sessions were deleted\(whenStopped).\(because)"
        }
        let deleted = "Deleted \(deletedCount.formatted()) of \(Self.sessionsPhrase(requestedCount))\(whenStopped).\(because)"
        switch stillListedCount {
        case ...0: return deleted
        case 1: return deleted + " The other one is still listed."
        default: return deleted + " The other \(stillListedCount.formatted()) are still listed."
        }
    }

    private var tryAgainStep: String? {
        let retriableFailures = retriableFailures
        guard !retriableFailures.isEmpty else { return nil }
        var hosts: [UnresponsiveSSHHost] = []
        for host in retriableFailures.compactMap(\.unresponsiveHost) where !hosts.contains(where: { $0.host == host.host }) {
            hosts.append(host)
        }
        let hostNames =
            hosts.count <= 2
            ? Self.listed(hosts.map { Self.shortened($0.host, to: 60) })
            : "\(hosts.count) hosts"
        guard retriableFailures.count < notDeletedCount else {
            let couldNotConnect = hosts.allSatisfy { if case .couldNotConnect = $0 { true } else { false } }
            guard couldNotConnect else { return "Choose Try Again to retry them." }
            let isOneHost = hosts.count == 1
            return "Choose Try Again once \(isOneHost ? hostNames : "the hosts") \(isOneHost ? "is" : "are") reachable."
        }
        let sessions = retriableFailures.count == 1 ? "the session" : "the \(Self.sessionsPhrase(retriableFailures.count))"
        return "Try Again retries \(sessions) on \(hostNames)."
    }

    private struct Cause {
        let text: String
        var explanation: String? = nil
        let sessionCount: Int
        var notDeletedCount = 0
    }

    private static func boundedCauses(_ causes: [Cause], besides reservedLength: Int) -> [String] {
        let overflowAllowance = 60
        var kept: [String] = []
        var length = reservedLength
        for (index, cause) in causes.enumerated() {
            let isLast = index == causes.count - 1
            let causeLimit = isLast ? maximumListedCauses : maximumListedCauses - 1
            let lengthLimit = isLast ? maximumMessageLength : maximumMessageLength - overflowAllowance
            guard kept.count < causeLimit, length + 2 + cause.text.count <= lengthLimit else { break }
            kept.append(cause.text)
            length += 2 + cause.text.count
        }
        let leftOutCount = causes.dropFirst(kept.count).reduce(0) { $0 + $1.sessionCount }
        guard leftOutCount > 0 else { return kept }
        return kept + ["Another \(sessionsPhrase(leftOutCount)) \(leftOutCount == 1 ? "wasn't" : "weren't") deleted."]
    }

    private static func listed(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + (items.last ?? "")
        }
    }

    private static func boundedOneSessionReason(_ reason: String) -> String {
        let lines = reason.split(separator: "\n", omittingEmptySubsequences: false)
        let keptLines = lines.prefix(maximumOneSessionReasonLines).joined(separator: "\n")
        let isCut = lines.count > maximumOneSessionReasonLines || keptLines.count > maximumOneSessionReasonLength
        return isCut ? keptLines.prefix(maximumOneSessionReasonLength - 1) + "…" : keptLines
    }

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

    private static func namedSessions(_ conversations: [Conversation], titleOf: (Conversation) -> String) -> String {
        let titles = conversations.prefix(2).map { "“\(shortened(titleOf($0), to: 24))”" }.joined(separator: " and ")
        return "\(sessionsPhrase(conversations.count)), \(conversations.count > 2 ? "including " : "")\(titles)"
    }

    private static func sentence(_ text: String) -> String {
        guard let last = text.last, !".!?…".contains(last) else { return text }
        return text + "."
    }

    private static func shortened(_ text: String, to limit: Int) -> String {
        let singleLine = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return singleLine.count > limit ? singleLine.prefix(limit - 1) + "…" : singleLine
    }
}
