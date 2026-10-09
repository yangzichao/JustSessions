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
        let runs = CheckRuns([(nil, Self.takeover), (0, Self.marker)])
        let (store, settings, host) = try makeStore(check: runs.check)
        defer { cleanUp(settings, host) }

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true)

        try await expectEventually { store.shellStartupCheck(on: host) != nil }
        let expected = RemoteShellStartupCheckResult(outcome: .usesLoginShellOnly, stoppedAt: "/home/me/.bashrc:7: exec tmux")
        #expect(store.shellStartupCheck(on: host) == expected)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == expected)
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)
        #expect(!store.hostsCheckingShellStartup.contains(host))
    }

    @Test func aCheckedHostIsCheckedAgainOnceARunWhenItsStatusSaysNothingAboutItsCLIs() async throws {
        let runs = CheckRuns([(nil, Self.takeover), (0, Self.marker)])
        let (store, settings, host) = try makeStore(saved: .interactiveStartupWorks, check: runs.check)
        defer { cleanUp(settings, host) }

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true)
        #expect(runs.count == 0)

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .usesLoginShellOnly }
        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(runs.count == 2)
    }

    @Test func aBlockedHostIsCheckedAgainOnlyWhenAsked() async throws {
        let runs = CheckRuns([(0, Self.marker)])
        let (store, settings, host) = try makeStore(saved: .blocked, check: runs.check)
        defer { cleanUp(settings, host) }

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(runs.count == 0)

        store.checkRemoteShellStartupNow(on: host)
        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .interactiveStartupWorks }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .interactive)
    }

    @Test func aSavedResultAppliesWhenTheAppStartsAndRemovingTheHostForgetsIt() throws {
        let (store, settings, host) = try makeStore(saved: .usesLoginShellOnly, check: CheckRuns([]).check)
        defer { cleanUp(settings, host) }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)

        store.removeRemoteHost(host)

        #expect(store.shellStartupCheck(on: host) == nil)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == nil)
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .interactive)
    }

    @Test func noOutcomeLeavesTheHostUncheckedForTheNextRefresh() async throws {
        let runs = CheckRuns([(255, "ssh: Could not resolve hostname")])
        let (store, settings, host) = try makeStore(check: runs.check)
        defer { cleanUp(settings, host) }

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: true)

        try await expectEventually { runs.count == 1 && !store.hostsCheckingShellStartup.contains(host) }
        #expect(store.shellStartupCheck(on: host) == nil)
        #expect(RemoteShellStartupChecks.load(from: settings.userDefaults).result(for: host) == nil)
    }

    /// Such a startup can make the refresh itself fail, as when it starts tmux in the shell an OpenCode snapshot runs in.
    @Test func aRefreshThatFailsChecksTheHost() async throws {
        let runs = CheckRuns([(nil, Self.takeover), (0, Self.marker)])
        let (store, settings, host) = try makeStore(check: runs.check)
        defer { cleanUp(settings, host) }

        store.refreshRemoteHost(host, discovery: try Self.discoveryThatFailsWithoutSSH())

        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .usesLoginShellOnly }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)
    }

    @Test func aHostThatCannotBeReachedIsTriedOnceARun() async throws {
        let runs = CheckRuns([(255, "ssh: connect to host port 22: Network is unreachable")])
        let (store, settings, host) = try makeStore(check: runs.check)
        defer { cleanUp(settings, host) }

        store.refreshRemoteHost(host, discovery: try Self.discoveryThatFailsWithoutSSH())
        try await expectEventually { runs.count == 1 && !store.hostsCheckingShellStartup.contains(host) }
        try await expectEventually { store.hostRefreshStatuses[.ssh(host)] != .refreshing }
        store.refreshRemoteHost(host, discovery: try Self.discoveryThatFailsWithoutSSH())
        try await expectEventually { store.hostRefreshStatuses[.ssh(host)] != .refreshing }
        try await Task.sleep(for: .milliseconds(100))

        #expect(runs.count == 1)
        #expect(store.shellStartupCheck(on: host) == nil)
    }

    /// Its copy's folder is a file, so the refresh fails before it would run `ssh`.
    private static func discoveryThatFailsWithoutSSH() throws -> RemoteSessionDiscovery {
        let notAFolder = FileManager.default.temporaryDirectory.appendingPathComponent("not-a-folder-\(UUID().uuidString.prefix(8))")
        try "".write(to: notAFolder, atomically: true, encoding: .utf8)
        return RemoteSessionDiscovery(mirror: RemoteSessionMirror(
            cacheRoot: notAFolder,
            sourceHomeOverride: FileManager.default.temporaryDirectory.path
        ))
    }

    private func makeStore(
        saved outcome: RemoteShellStartupCheckResult.Outcome? = nil,
        check: RemoteShellStartupCheck
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
            remoteShellStartupCheck: check,
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
