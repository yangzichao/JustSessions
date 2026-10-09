import Foundation
import Testing
@testable import JustSessions

/// When the store checks an SSH host's shell startup, and what it does with the result; see
/// `ConversationStore+RemoteShellStartup`. Each test has a host of its own, since the startups are the app's.
@MainActor
struct RemoteShellStartupStoreTests {
    private static let marker = "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n"
    private static let takeover = "+JUSTSESSIONS /home/me/.bashrc:7: exec tmux\r\n[0] 0:bash*"

    @Test func aHostNotCheckedYetIsCheckedAndItsCommandsFollowTheResult() async throws {
        let (store, settings, host) = try makeStore()
        defer { cleanUp(settings, host) }
        let runs = CheckRuns([(nil, Self.takeover), (0, Self.marker)])

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true, check: runs.check)

        try await expectEventually { store.shellStartupCheck(on: host) != nil }
        let expected = RemoteShellStartupCheckResult(outcome: .usesLoginShellOnly, stoppedAt: "/home/me/.bashrc:7: exec tmux")
        #expect(store.shellStartupCheck(on: host) == expected)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == expected)
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)
        #expect(!store.hostsCheckingShellStartup.contains(host))
    }

    @Test func aCheckedHostIsCheckedAgainOnceARunWhenItsStatusSaysNothingAboutItsCLIs() async throws {
        let (store, settings, host) = try makeStore(saved: .interactiveStartupWorks)
        defer { cleanUp(settings, host) }
        let runs = CheckRuns([(nil, Self.takeover), (0, Self.marker)])

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true, check: runs.check)
        #expect(runs.count == 0)

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false, check: runs.check)
        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .usesLoginShellOnly }
        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false, check: runs.check)
        try await Task.sleep(for: .milliseconds(100))
        #expect(runs.count == 2)
    }

    @Test func aBlockedHostIsCheckedAgainOnlyWhenAsked() async throws {
        let (store, settings, host) = try makeStore(saved: .blocked)
        defer { cleanUp(settings, host) }
        let runs = CheckRuns([(0, Self.marker)])

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false, check: runs.check)
        try await Task.sleep(for: .milliseconds(100))
        #expect(runs.count == 0)

        store.checkRemoteShellStartupAgain(on: host, check: runs.check)
        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .interactiveStartupWorks }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .interactive)
    }

    @Test func aSavedResultAppliesWhenTheAppStartsAndRemovingTheHostForgetsIt() throws {
        let (store, settings, host) = try makeStore(saved: .usesLoginShellOnly)
        defer { cleanUp(settings, host) }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)

        store.removeRemoteHost(host)

        #expect(store.shellStartupCheck(on: host) == nil)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == nil)
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .interactive)
    }

    @Test func noOutcomeLeavesTheHostUncheckedForTheNextRefresh() async throws {
        let (store, settings, host) = try makeStore()
        defer { cleanUp(settings, host) }
        let runs = CheckRuns([(255, "ssh: Could not resolve hostname")])

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true, check: runs.check)

        try await expectEventually { runs.count == 1 && !store.hostsCheckingShellStartup.contains(host) }
        #expect(store.shellStartupCheck(on: host) == nil)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == nil)
    }

    private func makeStore(
        saved outcome: RemoteShellStartupCheckResult.Outcome? = nil
    ) throws -> (ConversationStore, IsolatedUserDefaults, String) {
        let host = "shell-startup-\(UUID().uuidString.prefix(8).lowercased())"
        let settings = try IsolatedUserDefaults()
        RemoteHostList(hosts: [host]).save(to: settings.userDefaults)
        if let outcome {
            RemoteShellStartupChecks(resultsByHost: [host: RemoteShellStartupCheckResult(outcome: outcome, stoppedAt: nil)])
                .save(to: settings.userDefaults)
        }
        let store = ConversationStore(
            adapters: [PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))],
            userDefaults: settings.userDefaults,
            startsBackgroundPolling: false
        )
        return (store, settings, host)
    }

    private func cleanUp(_ settings: IsolatedUserDefaults, _ host: String) {
        settings.removeSuite()
        RemoteHostShellStartups.shared.setStartup(.interactive, on: host)
    }
}

/// A check whose runs answer with the recorded results, in order, and that counts them.
private final class CheckRuns: @unchecked Sendable {
    private let lock = NSLock()
    private var results: [(exitStatus: Int32?, output: String)]
    private var runCount = 0

    init(_ results: [(exitStatus: Int32?, output: String)]) {
        self.results = results
    }

    var count: Int { lock.withLock { runCount } }

    var check: RemoteShellStartupCheck {
        RemoteShellStartupCheck(run: { [self] _, _, _ in
            lock.withLock {
                runCount += 1
                return results.isEmpty ? nil : results.removeFirst()
            }
        })
    }
}
