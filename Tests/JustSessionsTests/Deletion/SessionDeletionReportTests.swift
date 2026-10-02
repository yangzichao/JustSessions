import Foundation
import Testing
@testable import JustSessions

struct SessionDeletionReportTests {
    // MARK: - One session

    @Test func oneSessionShowsTheReasonAloneUnderItsTitle() throws {
        let report = SessionDeletionReport(
            requestedCount: 1,
            deletedCount: 0,
            failures: [ConversationDeletionFailure(conversation: .fixture(title: "Refactor"), reason: "Codex exited with code 1")]
        )
        let alert = try #require(report.alert(titleOf: \.suggestedTitle))

        #expect(alert.title == "Couldn't delete “Refactor”")
        #expect(alert.message == "Codex exited with code 1")
        #expect(!alert.offersTryAgain)
    }

    @Test func oneSessionOnAHostThatDroppedOffersTryAgain() throws {
        let conversation = Conversation.fixture(title: String(repeating: "Long title ", count: 10), host: .ssh("devbox"))
        let error = RemoteConversationDeletionError.sshFailed(host: "devbox", details: "Timeout, server devbox not responding.")
        let report = SessionDeletionReport(requestedCount: 1, deletedCount: 0, failures: [
            ConversationDeletionFailure(conversation: conversation, reason: error.localizedDescription, unresponsiveHost: error.unresponsiveHost),
        ])
        let alert = try #require(report.alert(titleOf: \.suggestedTitle))

        #expect(alert.title == "Couldn't delete “Long title Long title Long title Long t…”")
        #expect(alert.message == "The connection to devbox was lost, for example because the Mac slept or the network changed.")
        #expect(alert.retryConversationIDs == [conversation.id])
    }

    @Test func oneSessionsLongReasonIsShortened() throws {
        let manyLines = (1...40).map { "Traceback line \($0)" }.joined(separator: "\n")
        let message = try #require(oneSessionReport(reason: manyLines).alert(titleOf: \.suggestedTitle)).message

        #expect(message.components(separatedBy: "\n").count == 6)
        #expect(message.hasPrefix("Traceback line 1\nTraceback line 2"))
        #expect(message.hasSuffix("Traceback line 6…"))
        #expect(try #require(oneSessionReport(reason: String(repeating: "x", count: 600)).alert(titleOf: \.suggestedTitle)).message.count == 300)
    }

    // MARK: - Several sessions

    @Test func noAlertWhenEverySessionWasDeleted() {
        #expect(SessionDeletionReport(requestedCount: 5, deletedCount: 5, failures: []).alert(titleOf: \.suggestedTitle) == nil)
    }

    @Test func aFewFailuresNameEachSessionAfterWhatWasDeleted() throws {
        let report = SessionDeletionReport(requestedCount: 3, deletedCount: 1, failures: [
            ConversationDeletionFailure(conversation: .fixture(provider: .claude, title: "Refactor"), reason: "Permission denied"),
            ConversationDeletionFailure(conversation: .fixture(provider: .codex, title: "Fix tests"), reason: "Exit code 7."),
        ])
        let alert = try #require(report.alert(titleOf: \.suggestedTitle))

        #expect(alert.title == "2 sessions weren't deleted")
        #expect(alert.message == """
            Deleted 1 of 3 sessions. The other 2 are still listed.

            Claude Code · Refactor: Permission denied.

            Codex · Fix tests: Exit code 7.
            """)
        #expect(!alert.offersTryAgain)
    }

    @Test func oneFailureAmongTwoIsSingular() throws {
        let report = SessionDeletionReport(requestedCount: 2, deletedCount: 1, failures: [
            ConversationDeletionFailure(conversation: .fixture(title: "Refactor"), reason: "Permission denied"),
        ])
        let alert = try #require(report.alert(titleOf: { "Custom \($0.suggestedTitle)" }))

        #expect(alert.title == "1 session wasn't deleted")
        #expect(alert.message == "Deleted 1 of 2 sessions. The other one is still listed.\n\nClaude Code · Custom Refactor: Permission denied.")
    }

    /// The lid closed after 37 of 140 sessions on devbox: the 38th lost its connection and the rest were skipped.
    /// One cause accounts for every session not deleted, so the summary tells it, then when to try again.
    @Test func aLostConnectionIsExplainedOnceWithTheSessionsItLeftAndTryAgain() throws {
        let failures = hostFailures(host: "devbox", count: 103, sshMessage: "Timeout, server devbox not responding.")
        let alert = try #require(SessionDeletionReport(requestedCount: 140, deletedCount: 37, failures: failures).alert(titleOf: \.suggestedTitle))

        #expect(alert.title == "103 sessions weren't deleted")
        #expect(alert.message == """
            Deleted 37 of 140 sessions. The connection to devbox was lost, for example because the Mac slept or the \
            network changed. The other 103 are still listed.

            Choose Try Again once devbox is reachable.
            """)
        #expect(alert.retryConversationIDs == Set(failures.map(\.conversation.id)))
    }

    @Test func aRefusedLoginIsNotRetried() throws {
        let failures = hostFailures(host: "devbox", count: 3, sshMessage: "me@devbox: Permission denied (publickey,password).")
        let alert = try #require(SessionDeletionReport(requestedCount: 3, deletedCount: 0, failures: failures).alert(titleOf: \.suggestedTitle))

        #expect(alert.message == """
            None of the 3 sessions were deleted. devbox didn't accept the SSH login without a password. Check that \
            “ssh devbox” works in Terminal without asking for a password.
            """)
        #expect(!alert.offersTryAgain)
    }

    @Test func tryAgainCoversOnlyTheSessionsOfHostsThatMayComeBack() throws {
        let lost = hostFailures(host: "devbox", count: 4, sshMessage: "client_loop: send disconnect: Broken pipe")
        let refused = hostFailures(host: "buildbox", count: 2, sshMessage: "Host key verification failed.")
        let local = [ConversationDeletionFailure(conversation: .fixture(title: "Locked"), reason: "Permission denied")]
        let alert = try #require(SessionDeletionReport(requestedCount: 10, deletedCount: 3, failures: lost + refused + local)
            .alert(titleOf: \.suggestedTitle))

        #expect(alert.title == "7 sessions weren't deleted")
        #expect(alert.message == """
            Deleted 3 of 10 sessions. The other 7 are still listed.

            The connection to devbox was lost, for example because the Mac slept or the network changed. 4 sessions on devbox weren't deleted.

            buildbox's host key has changed or isn't trusted. Connect once with “ssh buildbox” in Terminal to check it. \
            2 sessions on buildbox weren't deleted.

            Claude Code · Locked: Permission denied.

            Try Again retries the 4 sessions on devbox.
            """)
        #expect(alert.retryConversationIDs == Set(lost.map(\.conversation.id)))
    }

    @Test func aHostThatTimedOutMayStillHaveDeletedASession() throws {
        let error = RemoteConversationDeletionError.couldNotRun(host: "devbox")
        let failures = (0..<3).map { index in
            ConversationDeletionFailure(
                conversation: .fixture(title: "Session \(index)", host: .ssh("devbox")),
                reason: (index == 0 ? error : RemoteConversationDeletionError.notAttempted(error.unresponsiveHost!)).localizedDescription,
                unresponsiveHost: error.unresponsiveHost
            )
        }
        let local = ConversationDeletionFailure(conversation: .fixture(title: "Locked"), reason: "Permission denied")
        let alert = try #require(SessionDeletionReport(requestedCount: 5, deletedCount: 1, failures: failures + [local])
            .alert(titleOf: \.suggestedTitle))

        #expect(alert.message == """
            Deleted 1 of 5 sessions. The other 4 are still listed.

            Deleting on devbox didn't start or didn't finish within a minute. Refresh to see whether the session being \
            deleted is gone. 3 sessions on devbox may not have been deleted.

            Claude Code · Locked: Permission denied.

            Try Again retries the 3 sessions on devbox.
            """)
    }

    @Test func aCanceledDeletionSaysSo() throws {
        let report = SessionDeletionReport(
            requestedCount: 10,
            deletedCount: 2,
            failures: [ConversationDeletionFailure(conversation: .fixture(title: "Locked"), reason: "Permission denied")],
            wasCanceled: true
        )

        #expect(try #require(report.alert(titleOf: \.suggestedTitle)).message
            == "Deleted 2 of 10 sessions before you canceled. The other 8 are still listed.\n\nClaude Code · Locked: Permission denied.")
    }

    @Test func manyFailuresAreGroupedByReasonWithTheCountFirst() throws {
        let longTitle = "Investigate why the nightly build fails on the integration runners " + String(repeating: "and more ", count: 20)
        var failures = hostFailures(host: "devbox", count: 100, sshMessage: "ssh: connect to host devbox port 22: Operation timed out")
        failures += (0..<30).map { ConversationDeletionFailure(conversation: .fixture(title: "\($0) \(longTitle)"), reason: "Permission denied") }
        failures += (0..<15).map { _ in
            ConversationDeletionFailure(conversation: .fixture(title: longTitle), reason: "The index is locked.\n" + String(repeating: "details ", count: 40))
        }
        let alert = try #require(SessionDeletionReport(requestedCount: 1_200, deletedCount: 1_055, failures: failures).alert(titleOf: \.suggestedTitle))
        let lines = alert.message.components(separatedBy: "\n")

        #expect(alert.title == "145 sessions weren't deleted")
        #expect(lines[0] == "Deleted \(1_055.formatted()) of \(1_200.formatted()) sessions. The other 145 are still listed.")
        #expect(lines[1].isEmpty)
        #expect(lines[2] == "devbox didn't answer. Check your network or VPN. 100 sessions on devbox weren't deleted.")
        #expect(lines[4] == "30 sessions, including “0 Investigate why the n…” and “1 Investigate why the n…”: Permission denied.")
        #expect(lines[6].hasPrefix("15 sessions, including “Investigate why the nig…” and “Investigate why the nig…”: The index is locked. details"))
        #expect(lines[6].hasSuffix("…"))
        #expect(lines[8] == "Try Again retries the 100 sessions on devbox.")
        #expect(lines.count == 9)
    }

    @Test(arguments: [150, 1_000])
    func anyNumberOfFailuresStaysWithinTheBounds(failureCount: Int) throws {
        var failures: [ConversationDeletionFailure] = []
        failures += (0..<20).flatMap { index in
            hostFailures(host: "host-\(index)-" + String(repeating: "x", count: 200), count: 2, sshMessage: String(repeating: "y", count: 300))
        }
        failures += (0..<failureCount).map {
            ConversationDeletionFailure(conversation: .fixture(title: String(repeating: "t", count: 500)), reason: "Error \($0) " + String(repeating: "z", count: 600))
        }
        let alert = try #require(SessionDeletionReport(requestedCount: failures.count, deletedCount: 0, failures: failures)
            .alert(titleOf: \.suggestedTitle))
        let lines = alert.message.components(separatedBy: "\n")

        #expect(lines.count <= 11)
        #expect(alert.message.count <= SessionDeletionReport.maximumMessageLength)
        #expect(lines.first == "None of the \(failures.count.formatted()) sessions were deleted.")
        #expect(lines.contains { $0.hasPrefix("Another ") && $0.hasSuffix(" sessions weren't deleted.") })
        #expect(lines.last == "Try Again retries the 40 sessions on 20 hosts.")
    }

    // MARK: - Support

    private func oneSessionReport(reason: String) -> SessionDeletionReport {
        SessionDeletionReport(requestedCount: 1, deletedCount: 0, failures: [
            ConversationDeletionFailure(conversation: .fixture(title: "Refactor"), reason: reason),
        ])
    }

    /// The first session on `host` failed with `sshMessage`; the rest were skipped because of it.
    private func hostFailures(host: String, count: Int, sshMessage: String) -> [ConversationDeletionFailure] {
        let error = RemoteConversationDeletionError.sshFailed(host: host, details: sshMessage)
        let unresponsiveHost = error.unresponsiveHost
        return (0..<count).map { index in
            ConversationDeletionFailure(
                conversation: .fixture(title: "Session \(index)", host: .ssh(host)),
                reason: index == 0 ? error.localizedDescription : RemoteConversationDeletionError.notAttempted(unresponsiveHost!).localizedDescription,
                unresponsiveHost: unresponsiveHost
            )
        }
    }
}
