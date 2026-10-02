import Testing
@testable import JustSessions

struct ConversationDeletionFailureTests {
    @Test func oneSessionShowsTheReasonAlone() {
        let failure = ConversationDeletionFailure(conversation: .fixture(title: "Refactor"), reason: "Codex exited with code 1")
        #expect(ConversationDeletionFailure.messageAfterDeletingOneSession([failure]) == "Codex exited with code 1")
    }

    @Test func severalSessionsNameEachFailedSessionAndItsTool() {
        let failures = [
            ConversationDeletionFailure(conversation: .fixture(provider: .claude, title: "Refactor"), reason: "Permission denied"),
            ConversationDeletionFailure(conversation: .fixture(provider: .codex, title: "Fix tests"), reason: "Exit code 7"),
        ]
        #expect(ConversationDeletionFailure.messageAfterDeletingSeveralSessions(failures) == """
            Some sessions could not be deleted:
            Claude Code · Refactor: Permission denied
            Codex · Fix tests: Exit code 7
            """)
    }

    @Test func aFewFailuresShortenLongTitlesAndReasonsToOneLineEach() {
        let failures = [
            ConversationDeletionFailure(
                conversation: .fixture(title: String(repeating: "Long title ", count: 30)),
                reason: "Could not delete the session on devbox:\n" + String(repeating: "Traceback line\n", count: 40)
            ),
            ConversationDeletionFailure(conversation: .fixture(title: "Short"), reason: "Permission denied"),
        ]
        let lines = ConversationDeletionFailure.messageAfterDeletingSeveralSessions(failures).components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[1].hasPrefix("Claude Code · Long title Long title Long title Long t…: Could not delete the session on devbox: Traceback"))
        #expect(lines[1].hasSuffix("…"))
        #expect(lines[1].count <= 180)
        #expect(lines[2] == "Claude Code · Short: Permission denied")
    }

    @Test func oneSessionsLongReasonIsShortened() {
        let failure = ConversationDeletionFailure(
            conversation: .fixture(title: "Refactor"),
            reason: (1...40).map { "Traceback line \($0)" }.joined(separator: "\n")
        )
        let message = ConversationDeletionFailure.messageAfterDeletingOneSession([failure])

        #expect(message.components(separatedBy: "\n").count == 6)
        #expect(message.hasPrefix("Traceback line 1\nTraceback line 2"))
        #expect(message.hasSuffix("Traceback line 6…"))
        #expect(ConversationDeletionFailure.messageAfterDeletingOneSession([
            ConversationDeletionFailure(conversation: .fixture(), reason: String(repeating: "x", count: 600)),
        ]).count == 300)
    }

    @Test func manyFailuresAreGroupedByReasonAndStayShort() {
        let longTitle = "Investigate why the nightly build fails on the integration runners " + String(repeating: "and more ", count: 20)
        let longReason = "Could not delete the session on buildbox: " + String(repeating: "rm: cannot remove: Directory not empty\n", count: 20)
        let unreachable = UnresponsiveSSHHost.couldNotConnect(host: "devbox")
        let unreachableReason = RemoteConversationDeletionError.notAttempted(unreachable).localizedDescription
        var failures: [ConversationDeletionFailure] = []
        failures += (0..<100).map { failure(title: "\(longTitle) \($0)", reason: unreachableReason, unresponsiveHost: unreachable) }
        failures += (0..<30).map { failure(title: "\($0) \(longTitle)", reason: "Permission denied") }
        failures += (0..<15).map { _ in failure(title: longTitle, reason: longReason) }
        failures += (0..<6).map { failure(title: "Unique \($0)", reason: "Error \($0): " + String(repeating: "x", count: 400)) }
        failures += [failure(title: "Slow", reason: "timed out", unresponsiveHost: .didNotRespondInTime(host: "buildbox"))]

        let message = ConversationDeletionFailure.messageAfterDeletingSeveralSessions(failures)
        let lines = message.components(separatedBy: "\n")

        #expect(lines.count <= 10)
        #expect(message.count <= 1_500)
        #expect(lines[0] == "Some sessions could not be deleted:")
        #expect(lines[1] == "devbox could not be reached, so 100 sessions on it were not deleted.")
        #expect(lines[2] == "buildbox did not respond in time, so 1 session on it was not deleted.")
        #expect(lines[3] == "30 sessions, including “0 Investigate why the n…” and “1 Investigate why the n…”: Permission denied")
        #expect(lines[4].hasPrefix("15 sessions, including “Investigate why the nig…” and “Investigate why the nig…”: Could not delete"))
        #expect(lines[5].hasPrefix("Claude Code · Unique 0: Error 0: xxx"))
        #expect(lines.count == 9)
        #expect(lines[8] == "3 more sessions could not be deleted.")
    }

    @Test func manyDifferentReasonsAndHostsStillFitTheAlert() {
        var failures: [ConversationDeletionFailure] = []
        failures += (0..<20).map {
            failure(title: "On host \($0)", reason: "unreachable", unresponsiveHost: .couldNotConnect(host: "host-\($0)-" + String(repeating: "x", count: 200)))
        }
        failures += (0..<1_000).map { failure(title: String(repeating: "t", count: 500), reason: "Error \($0) " + String(repeating: "y", count: 600)) }

        let message = ConversationDeletionFailure.messageAfterDeletingSeveralSessions(failures)
        let lines = message.components(separatedBy: "\n")

        #expect(lines.count <= 10)
        #expect(message.count <= 1_500)
        #expect(lines.last == "\(1_013.formatted()) more sessions could not be deleted.")
    }

    private func failure(title: String, reason: String, unresponsiveHost: UnresponsiveSSHHost? = nil) -> ConversationDeletionFailure {
        ConversationDeletionFailure(conversation: .fixture(title: title, host: .ssh("devbox")), reason: reason, unresponsiveHost: unresponsiveHost)
    }
}
