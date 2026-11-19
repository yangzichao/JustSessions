import Foundation
import Testing

@testable import JustSessions

@MainActor
struct BackgroundHostCheckStoreTests {
    @Test func keepsTheReportWithoutRunningTheShellStartupTraceAgain() async throws {
        let tracedStartups = TracedStartupCounter()
        let (store, settings, host) = try makeStore(
            tmuxServerOutput: "protocol version mismatch (client 8, server 7)", tracedStartups: tracedStartups)
        defer { cleanUp(settings, host) }

        let check = try #require(store.checkHostInBackground(host))
        await check.value

        let keptCheck = try #require(store.keptHostChecks.check(for: host))
        #expect(keptCheck.appVersion == FeedbackEnvironment.current.appVersion)
        #expect(keptCheck.report.findings.contains { $0.id == .tmux && $0.status == .problem })
        #expect(KeptHostChecks.load(from: settings.userDefaults) == store.keptHostChecks)
        #expect(tracedStartups.count == 0)
        #expect(store.hostCheck == nil)
        let warning = try #require(store.hostCheckProblemMessage(on: host))
        #expect(warning.hasPrefix("tmux: "))
    }

    @Test func theHeadingWarnsOfWhatTheLastRefreshsTmuxPrintedAndItsWarningChecksTheHost() async throws {
        let (store, settings, host) = try makeStore()
        defer { cleanUp(settings, host) }
        await store.checkHostInBackground(host)?.value
        let keptReport = try #require(store.keptHostChecks.check(for: host)?.report)
        #expect(store.hostCheckProblemMessage(on: host) == nil)

        store.showHostCheck(host)
        #expect(store.hostCheck?.report == keptReport)

        store.hostCheck = nil
        store.setTmuxServerProblem("protocol version mismatch (client 8, server 7)", on: host)
        #expect(
            store.hostCheckProblemMessage(on: host)
                == AppLocalization.string(
                    "tmux on \(host) can't reach the tmux server running there, so its sessions can't be opened: protocol version mismatch (client 8, server 7)"
                ))
        store.showHostCheck(host)
        #expect(store.hostCheck?.isChecking == true)
        store.hostCheck = nil
    }

    @Test func removingTheHostForgetsItsChecks() async throws {
        let (store, settings, host) = try makeStore()
        defer { cleanUp(settings, host) }
        await store.checkHostInBackground(host)?.value
        store.setTmuxServerProblem("server exited unexpectedly", on: host)

        store.removeRemoteHost(host)

        #expect(store.keptHostChecks.check(for: host) == nil)
        #expect(KeptHostChecks.load(from: settings.userDefaults).check(for: host) == nil)
        #expect(store.hostCheckProblemMessage(on: host) == nil)
    }

    private func makeStore(
        tmuxServerOutput: String = "no server running on /tmp/tmux-1000/default",
        tracedStartups: TracedStartupCounter = TracedStartupCounter()
    ) throws -> (ConversationStore, IsolatedUserDefaults, String) {
        let host = "background-check-\(UUID().uuidString.prefix(8).lowercased())"
        let settings = try IsolatedUserDefaults()
        RemoteHostList(hosts: [host]).save(to: settings.userDefaults)
        RemoteShellStartupChecks(resultsByHost: [host: RemoteShellStartupCheckResult(outcome: .interactiveStartupWorks, stoppedAt: nil)])
            .save(to: settings.userDefaults)
        let remoteHostCheck = RemoteHostCheck(
            runner: RemoteHostCommandRunner { _, _, _ in
                (
                    0,
                    hostCheckScriptOutput([
                        "shell": "/bin/bash",
                        "rsync-path": "/usr/bin/rsync",
                        "rsync-version": "rsync  version 3.2.7  protocol version 31",
                        "tmux-path": "/usr/bin/tmux",
                        "tmux-version": "tmux 3.4",
                        "tmux-server": tmuxServerOutput,
                        "tmux-server-exit": "1",
                    ])
                )
            },
            connectionCheck: RemoteHostConnectionCheck(runner: RemoteHostCommandRunner { _, _, _ in (0, "%OS% :OS\n") }),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in
                tracedStartups.increment()
                return (0, "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n")
            })
        )
        let store = ConversationStore(
            adapters: [PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))],
            userDefaults: settings.userDefaults,
            remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }),
            remoteHostCheck: remoteHostCheck,
            startsBackgroundPolling: false
        )
        return (store, settings, host)
    }

    private func cleanUp(_ settings: IsolatedUserDefaults, _ host: String) {
        settings.removeSuite()
        RemoteHostShellStartups.shared.setStartup(.interactive, on: host)
        RemoteHostCLILocations.shared.forgetLocations(on: host)
    }
}

private final class TracedStartupCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    var count: Int { lock.withLock { calls } }

    func increment() {
        lock.withLock { calls += 1 }
    }
}
