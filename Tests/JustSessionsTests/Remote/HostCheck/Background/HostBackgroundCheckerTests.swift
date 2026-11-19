import Foundation
import Testing

@testable import JustSessions

/// Which host `HostBackgroundChecker` checks, one at a time; the checks themselves are faked.
@MainActor
struct HostBackgroundCheckerTests {
    @Test func checksADueHostOnceAtATime() async throws {
        let (store, settings) = try makeStore(hosts: ["devbox", "buildbox"])
        defer { settings.removeSuite() }
        let gate = AsyncGate()
        var checkedHosts: [String] = []
        let checker = HostBackgroundChecker(
            appVersion: { "1.2.11" },
            checkHost: { _, host in
                checkedHosts.append(host)
                return Task { await gate.wait() }
            })

        checker.checkDueHost(in: [store])
        checker.checkDueHost(in: [store])

        #expect(checkedHosts == ["devbox"])
        #expect(checker.hostBeingChecked == "devbox")
        await gate.open()
        try await expectEventually { checker.hostBeingChecked == nil }
        // Its fake check kept no report, so it is still due; the other host's turn comes after it.
        checker.checkDueHost(in: [store])
        #expect(checkedHosts == ["devbox", "devbox"])
    }

    @Test func leavesAHostThatDidntRefreshNeedsConnectIsDisconnectedOrHasNoShellStartupYet() throws {
        let (store, settings) = try makeStore(
            hosts: ["failed", "needs-login", "disconnected", "unchecked-startup"],
            shellStartupHosts: ["failed", "needs-login", "disconnected"]
        )
        defer { settings.removeSuite() }
        store.hostRefreshStatuses[.ssh("failed")] = .failed("ssh: connect to host failed")
        store.sshHostsNeedingLogIn = ["needs-login"]
        store.disconnectedRemoteHosts.setDisconnected(true, for: "disconnected")
        var checkedHosts: [String] = []
        let checker = HostBackgroundChecker(
            appVersion: { "1.2.11" },
            checkHost: { _, host in
                checkedHosts.append(host)
                return Task {}
            })

        checker.checkDueHost(in: [store])

        #expect(checkedHosts.isEmpty)
    }

    @Test func aTabThatEndedSoonAfterItStartedHasItsHostCheckedAndTheAskIsCleared() throws {
        let (store, settings) = try makeStore(hosts: ["devbox"])
        defer { settings.removeSuite() }
        var keptChecks = KeptHostChecks()
        keptChecks.setCheck(
            KeptHostCheck(
                report: HostCheckReport(host: "devbox", checkedAt: .now.addingTimeInterval(-15 * 60), thisMacSummary: "", findings: []),
                appVersion: "1.2.11"
            ),
            for: "devbox"
        )
        store.keptHostChecks = keptChecks
        var checkedHosts: [String] = []
        let checker = HostBackgroundChecker(
            appVersion: { "1.2.11" },
            checkHost: { _, host in
                checkedHosts.append(host)
                return Task {}
            })

        checker.checkDueHost(in: [store])
        #expect(checkedHosts.isEmpty)

        store.hostsAskingForBackgroundCheck = ["devbox"]
        checker.checkDueHost(in: [store])
        #expect(checkedHosts == ["devbox"])
        #expect(store.hostsAskingForBackgroundCheck.isEmpty)
    }

    private func makeStore(hosts: [String], shellStartupHosts: [String]? = nil) throws -> (ConversationStore, IsolatedUserDefaults) {
        let settings = try IsolatedUserDefaults()
        RemoteHostList(hosts: hosts).save(to: settings.userDefaults)
        RemoteShellStartupChecks(
            resultsByHost: Dictionary(
                uniqueKeysWithValues: (shellStartupHosts ?? hosts).map {
                    ($0, RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil))
                })
        ).save(to: settings.userDefaults)
        let store = ConversationStore(
            adapters: [PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))],
            userDefaults: settings.userDefaults,
            remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }),
            startsBackgroundPolling: false
        )
        for host in hosts { store.hostRefreshStatuses[.ssh(host)] = .refreshed(.now) }
        return (store, settings)
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        for waiter in waiters { waiter.resume() }
        waiters.removeAll()
    }
}
