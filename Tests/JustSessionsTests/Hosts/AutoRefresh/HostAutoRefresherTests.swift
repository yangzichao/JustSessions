import Foundation
import Testing

@testable import JustSessions

/// The periodic check refreshes the hosts only while a window shows; coming forward refreshes them anyway. This Mac
/// refreshes in every window, sharing one scan; an SSH host is copied by the oldest window alone.
@MainActor
struct HostAutoRefresherTests {
    @Test func theCheckRefreshesNothingWhileNoWindowShows() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        try await Self.finishFirstRefresh(of: sandbox)
        let copies = SSHHostCopies()
        let refresher = HostAutoRefresher(registry: sandbox.windowRegistry, isAnyWindowOnScreen: { false }, refreshSSHHost: copies.start)
        let startedAt = sandbox.first.lastRefreshStartedAt

        refresher.check(now: .now + 3_600)

        #expect(sandbox.first.lastRefreshStartedAt == startedAt)
        #expect(copies.started.isEmpty)
    }

    @Test func thisMacRefreshesInEveryWindowOnceAMinuteHasPassed() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        try await Self.finishFirstRefresh(of: sandbox)
        let refresher = HostAutoRefresher(
            registry: sandbox.windowRegistry, isAnyWindowOnScreen: { true }, refreshSSHHost: SSHHostCopies().start)
        let firstStartedAt = try #require(sandbox.first.lastRefreshStartedAt)
        let secondStartedAt = try #require(sandbox.second.lastRefreshStartedAt)

        refresher.check(now: firstStartedAt + 30)
        #expect(sandbox.first.lastRefreshStartedAt == firstStartedAt)

        refresher.check(now: firstStartedAt + 60)
        #expect(sandbox.first.lastRefreshStartedAt != firstStartedAt)
        #expect(sandbox.second.lastRefreshStartedAt != secondStartedAt)
    }

    @Test func onlyTheOldestWindowCopiesADueSSHHost() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        let copiedAt = Date.now - 300
        for store in [sandbox.first, sandbox.second] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox", "buildbox"])
            store.hostRefreshStatuses[.ssh("devbox")] = .refreshed(copiedAt)
            store.hostRefreshStatuses[.ssh("buildbox")] = .refreshed(.now)
        }
        let copies = SSHHostCopies()
        // As when the app comes forward before its window counts as on screen.
        let refresher = HostAutoRefresher(registry: sandbox.windowRegistry, isAnyWindowOnScreen: { false }, refreshSSHHost: copies.start)

        refresher.refreshDueHosts(now: .now)
        refresher.refreshDueHosts(now: .now)

        #expect(copies.started.count == 1)
        #expect(copies.started.first?.store === sandbox.first)
        #expect(copies.started.first?.host == "devbox")
    }

    /// You disconnected from the host, so it is left alone until you connect; see `ConversationStore+RemoteHostDisconnect`.
    @Test func aDisconnectedHostIsLeftAlone() async throws {
        let sandbox = try TwoWindowSandbox()
        defer { sandbox.tearDown() }
        for store in [sandbox.first, sandbox.second] {
            store.remoteHostList = RemoteHostList(hosts: ["devbox", "buildbox"])
            store.hostRefreshStatuses[.ssh("devbox")] = .refreshed(.now - 3_600)
            store.hostRefreshStatuses[.ssh("buildbox")] = .refreshed(.now - 3_600)
            store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        }
        let copies = SSHHostCopies()
        let refresher = HostAutoRefresher(registry: sandbox.windowRegistry, isAnyWindowOnScreen: { true }, refreshSSHHost: copies.start)

        refresher.refreshDueHosts(now: .now)

        #expect(copies.started.map(\.host) == ["buildbox"])
    }

    private static func finishFirstRefresh(of sandbox: TwoWindowSandbox) async throws {
        for store in [sandbox.first, sandbox.second] { store.refreshThisMac() }
        try await expectEventually { !sandbox.first.isScanningThisMac && !sandbox.second.isScanningThisMac }
    }
}

/// Stands in for `refreshRemoteHost(_:)`: marks the host refreshing, as it does, and records which window started it.
@MainActor
private final class SSHHostCopies {
    private(set) var started: [(store: ConversationStore, host: String)] = []

    func start(_ store: ConversationStore, _ host: String) -> Task<Void, Never>? {
        guard store.hostRefreshStatuses[.ssh(host)] != .refreshing else { return nil }
        store.hostRefreshStatuses[.ssh(host)] = .refreshing
        started.append((store, host))
        return Task {}
    }
}
