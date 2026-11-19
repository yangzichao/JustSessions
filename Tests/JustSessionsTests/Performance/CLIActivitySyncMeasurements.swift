import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct CLIActivitySyncMeasurements {
    private static let thisMacSessionCount = 365
    private static let syncCount = 30

    @Test(arguments: [(listed: 3_365, running: 58), (listed: 10_365, running: 100)])
    func aSyncWithSessionsRunningInTmuxAndNoTab(_ counts: (listed: Int, running: Int)) async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        RemoteHostList(hosts: ["devbox"]).save(to: settings.userDefaults)
        let store = ConversationStore(
            adapters: [], userDefaults: settings.userDefaults, sessionNotifier: RecordingSessionNotifier(), startsBackgroundPolling: false)
        let thisMacConversations = Self.conversations(Self.thisMacSessionCount, on: .thisMac)
        let hostConversations = Self.conversations(counts.listed - Self.thisMacSessionCount, on: .ssh("devbox"))
        store.replaceConversations(on: .thisMac, with: thisMacConversations)
        store.replaceConversations(on: .ssh("devbox"), with: hostConversations)
        let runningOnThisMac = Self.spread(counts.running / 2, over: thisMacConversations)
        let runningOnHost = Self.spread(counts.running - counts.running / 2, over: hostConversations)
        store.tmuxSessionNamesByHost[.thisMac] = Set(runningOnThisMac.map(TmuxSessionName.forConversation))
        store.tmuxSessionNamesByHost[.ssh("devbox")] = Set(runningOnHost.map(TmuxSessionName.forConversation))
        store.sshHostsNeedingLogIn.insert("devbox")
        let claudeRegistry = ClaudeLiveSessionRegistry(configurationDirectory: directory.appendingPathComponent("claude"))

        await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry, liveSessionReporting: nil)
        var cpuTimes: [Duration] = []
        var wallTimes: [Duration] = []
        for _ in 0..<Self.syncCount {
            let clock = ContinuousClock()
            let start = clock.now
            let cpuStart = Self.mainThreadCPUTime()
            await store.synchronizeCLIActivity(claudeRegistry: claudeRegistry, liveSessionReporting: nil)
            cpuTimes.append(Self.mainThreadCPUTime() - cpuStart)
            wallTimes.append(clock.now - start)
        }
        #expect(store.remoteDetachedSince.count == runningOnHost.count, "The sync didn't find the host's sessions running with no tab.")

        let cpuSorted = cpuTimes.sorted()
        let wallSorted = wallTimes.sorted()
        let scenario = "\(counts.listed) listed, \(counts.running) in tmux with no tab"
        perfReport("CLIActivitySync", "\(scenario): median main-thread CPU a sync", cpuSorted[cpuSorted.count / 2])
        perfReport("CLIActivitySync", "\(scenario): p90 main-thread CPU a sync", cpuSorted[cpuSorted.count * 9 / 10])
        perfReport("CLIActivitySync", "\(scenario): median sync, wall clock", wallSorted[wallSorted.count / 2])
        perfReport("CLIActivitySync", "\(scenario): longest sync, wall clock", wallSorted[wallSorted.count - 1])
    }

    private static func mainThreadCPUTime() -> Duration {
        .nanoseconds(clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID))
    }

    private static func spread(_ count: Int, over conversations: [Conversation]) -> [Conversation] {
        stride(from: 0, to: conversations.count, by: max(1, conversations.count / count)).prefix(count).map { conversations[$0] }
    }

    private static func conversations(_ count: Int, on host: SessionHost) -> [Conversation] {
        let now = Date.now
        return (0..<count).map { index in
            .fixture(
                provider: .claude,
                projectPath: "/srv/projects/project-\(index % 50)",
                title: "Session \(index): a typical prompt-length title for the sidebar",
                updatedAt: now.addingTimeInterval(-Double(index) * 60),
                host: host
            )
        }
    }
}
