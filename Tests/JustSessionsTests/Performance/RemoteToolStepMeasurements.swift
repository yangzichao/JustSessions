import Foundation
import Testing

@testable import JustSessions

/// Measures listing one tool's copy from an SSH host with thousands of sessions when the copy found what the last one
/// did, which is what most of a refresh's 6 tool steps find. Before PERF-88 each step sorted, compared, and published
/// the whole list again. Reports `Perf | RemoteToolStep | …` lines.
///
/// The suite records nothing unless `JUSTSESSIONS_PERF` is set:
///     JUSTSESSIONS_PERF=1 swift test -c release --filter RemoteToolStepMeasurements
@MainActor
@Suite(.serialized)
struct RemoteToolStepMeasurements {
    private static let stepCount = 30

    @Test(arguments: [3_000, 10_000])
    func aToolStepThatChangesNothing(sessionCount: Int) throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let sandbox = try TabReopeningSandbox(remoteHosts: ["devbox"])
        defer { sandbox.tearDown() }
        let store = sandbox.makeStore()
        let now = Date.now
        let hostConversations: [Conversation] = (0..<sessionCount).map { index in
            .fixture(
                provider: index % 3 == 0 ? .codex : .claude,
                projectPath: "/srv/projects/project-\(index % 50)",
                title: "Session \(index): a typical prompt-length title for the sidebar",
                updatedAt: now.addingTimeInterval(-Double(index) * 60),
                host: .ssh("devbox")
            )
        }
        store.replaceConversations(on: .ssh("devbox"), with: hostConversations)
        // In the adapter's order, which is the folder's, not the list's.
        let claudeConversations = hostConversations.filter { $0.provider == .claude }.shuffled()
        let step = RemoteSessionCopyStep(provider: .claude, number: 1, count: ConversationProvider.allCases.count)

        var durations: [Duration] = []
        for _ in 0..<Self.stepCount {
            let clock = ContinuousClock()
            let start = clock.now
            store.applyRemoteHostConversations(claudeConversations, of: step, host: "devbox")
            durations.append(clock.now - start)
        }
        #expect(store.conversations.count == sessionCount)

        let sorted = durations.sorted()
        perfReport("RemoteToolStep", "\(sessionCount) sessions, unchanged tool: median step", sorted[sorted.count / 2])
        perfReport("RemoteToolStep", "\(sessionCount) sessions, unchanged tool: longest step", sorted[sorted.count - 1])
    }
}
