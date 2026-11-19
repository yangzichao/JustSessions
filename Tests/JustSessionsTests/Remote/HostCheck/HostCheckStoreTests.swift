import Foundation
import Testing

@testable import JustSessions

/// How a window's store runs Check this host… and shows its report; see `ConversationStore+HostCheck`. Each test has a
/// host of its own, since shell startups are the app's.
@Suite(.oneHeldThreadAtATime)
@MainActor
struct HostCheckStoreTests {
    @Test func showsTheCheckWhileItRunsThenItsReportAndKeepsTheShellStartupItFound() async throws {
        let gate = CheckGate()
        let (store, settings, host) = try makeStore(gate: gate, shellStartupOutput: "Welcome to fish\r\nme@host ~> ")
        defer { cleanUp(settings, host) }

        store.checkHost(host)

        #expect(store.hostCheck?.host == host)
        #expect(store.hostCheck?.isChecking == true)
        gate.open()
        try await expectEventually { store.hostCheck?.report != nil }
        #expect(store.hostCheck?.report?.findings.first?.id == .connection)
        #expect(store.shellStartupCheck(on: host)?.outcome == .usesLoginShellOnly)
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .loginOnly)
    }

    @Test func showsEachStepAsTheCheckReachesIt() async throws {
        let gate = CheckGate()
        let scriptGate = CheckGate()
        let (store, settings, host) = try makeStore(gate: gate, scriptGate: scriptGate)
        defer { cleanUp(settings, host) }

        store.checkHost(host)

        #expect(store.hostCheck?.step == .logIn)
        let loginStartedAt = try #require(store.hostCheck?.stepStartedAt)
        gate.open()
        try await expectEventually { store.hostCheck?.step == .hostCommand }
        #expect(store.hostCheck?.isChecking == true)
        #expect(try #require(store.hostCheck?.stepStartedAt) >= loginStartedAt)
        scriptGate.open()
        try await expectEventually { store.hostCheck?.report != nil }
        #expect(store.hostCheck?.step == .hostCommand)
    }

    @Test func checkAgainReplacesTheReportAndAClosedSheetStaysClosed() async throws {
        let gate = CheckGate()
        let (store, settings, host) = try makeStore(gate: gate)
        defer { cleanUp(settings, host) }
        gate.open()
        store.checkHost(host)
        try await expectEventually { store.hostCheck?.report != nil }
        let firstRunID = try #require(store.hostCheck?.runID)

        gate.close()
        store.checkShownHostAgain()
        #expect(store.hostCheck?.isChecking == true)
        #expect(store.hostCheck?.step == .logIn)
        #expect(store.hostCheck?.runID != firstRunID)
        store.hostCheck = nil
        gate.open()
        try await expectEventually { gate.loginCount == 2 }
        try await Task.sleep(for: .milliseconds(100))

        #expect(store.hostCheck == nil)
    }

    @Test func aBlockedHostIsCheckedAgainFromCheckThisHost() async throws {
        let gate = CheckGate()
        gate.open()
        let (store, settings, host) = try makeStore(gate: gate, saved: .blocked)
        defer { cleanUp(settings, host) }

        store.checkRemoteShellStartupIfNeeded(on: host, statusListedCLIs: false)
        try await Task.sleep(for: .milliseconds(100))
        #expect(gate.automaticCheckCount == 0)

        store.checkHost(host)
        try await expectEventually { store.shellStartupCheck(on: host)?.outcome == .interactiveStartupWorks }
        #expect(RemoteHostShellStartups.shared.startup(on: host) == .interactive)
    }

    private func makeStore(
        gate: CheckGate,
        scriptGate: CheckGate? = nil,
        saved outcome: RemoteShellStartupCheckResult.Outcome? = nil,
        shellStartupOutput: String = "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n"
    ) throws -> (ConversationStore, IsolatedUserDefaults, String) {
        let host = "host-check-\(UUID().uuidString.prefix(8).lowercased())"
        let settings = try IsolatedUserDefaults()
        RemoteHostList(hosts: [host]).save(to: settings.userDefaults)
        if let outcome {
            RemoteShellStartupChecks(resultsByHost: [host: RemoteShellStartupCheckResult(outcome: outcome, stoppedAt: nil)])
                .save(to: settings.userDefaults)
        }
        let remoteHostCheck = RemoteHostCheck(
            runner: RemoteHostCommandRunner { _, command, _ in
                if !command.contains(RemoteHostStatusProbe.installFoldersHeading) { scriptGate?.waitUntilOpen() }
                return (0, hostCheckScriptOutput(["shell": "/bin/bash"]))
            },
            connectionCheck: RemoteHostConnectionCheck(
                runner: RemoteHostCommandRunner { _, _, _ in
                    gate.waitUntilOpen()
                    return (0, "%OS% :OS\n")
                }),
            shellStartupCheck: RemoteShellStartupCheck(run: { _, command, _ in
                command == RemoteShellStartupCheck.tracedInteractiveCommand
                    ? (0, shellStartupOutput)
                    : (0, "__JUSTSESSIONS_SHELL_STARTUP_OK__\r\n")
            })
        )
        let store = ConversationStore(
            adapters: [PiAdapter(sessionsDirectory: URL(fileURLWithPath: "/unused"))],
            userDefaults: settings.userDefaults,
            remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in
                gate.countAutomaticCheck()
                return nil
            }),
            remoteHostCheck: remoteHostCheck,
            startsBackgroundPolling: false
        )
        return (store, settings, host)
    }

    private func cleanUp(_ settings: IsolatedUserDefaults, _ host: String) {
        settings.removeSuite()
        RemoteHostShellStartups.shared.setStartup(.interactive, on: host)
    }
}

/// Holds each host check at its login, or at its script, until opened, and counts the checks it held and the store's
/// own shell startup checks.
private final class CheckGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var isOpen = false
    private var logins = 0
    private var automaticChecks = 0

    var loginCount: Int { condition.withLock { logins } }
    var automaticCheckCount: Int { condition.withLock { automaticChecks } }

    func open() {
        condition.withLock {
            isOpen = true
            condition.broadcast()
        }
    }

    func close() {
        condition.withLock { isOpen = false }
    }

    func countAutomaticCheck() {
        condition.withLock { automaticChecks += 1 }
    }

    func waitUntilOpen() {
        condition.withLock {
            logins += 1
            while !isOpen { condition.wait() }
        }
    }
}
