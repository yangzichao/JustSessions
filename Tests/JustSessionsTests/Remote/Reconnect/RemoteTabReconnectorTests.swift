import Foundation
import Testing

@testable import JustSessions

@MainActor
struct RemoteTabReconnectorTests {
    @Test func closingTheLastDroppedTabBeforeItsFirstTryStartsNoProbe() throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.drop(setup.tab)
        setup.sandbox.first.closeTerminal(setup.tab.id)

        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()
        setup.reconnector.tryAgain()
        setup.clock.advance(by: 60)
        setup.reconnector.askDueHosts()

        #expect(setup.host.askCount.value == 0)
        #expect(setup.sandbox.first.terminalSessions.isEmpty)
    }

    @Test func closingTheLastDroppedTabAfterAFailureStopsRetries() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()
        try await setup.waitForAnswer(number: 1)
        setup.sandbox.first.closeTerminal(setup.tab.id)

        setup.clock.advance(by: 5)
        setup.reconnector.askDueHosts()

        #expect(setup.host.askCount.value == 1)
        #expect(!setup.reconnector.isAsking("devbox"))
    }

    @Test func aDroppedTabIsReconnectedInItsPlaceOnceTheHostListsItsTmuxSession() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [setup.tmuxSessionName, "justsessions-codex-other"] }
        let store = setup.sandbox.first
        store.selectTerminal(setup.tab.id)

        setup.drop(setup.tab)
        #expect(setup.tab.isWaitingToReconnect)
        setup.clock.advance(by: 1.9)
        setup.reconnector.askDueHosts()
        #expect(setup.host.askCount.value == 0)
        setup.clock.advance(by: 0.1)
        setup.reconnector.askDueHosts()

        try await expectEventually { store.terminalSessions.first?.id != setup.tab.id }
        let replacement = try #require(store.terminalSessions.first)
        #expect(store.terminalSessions.count == 1)
        #expect(!replacement.hasExited)
        #expect(replacement.host == .ssh("devbox"))
        #expect(replacement.tmuxSessionName == setup.tmuxSessionName)
        #expect(store.selectedTerminalID == replacement.id)
        #expect(!setup.tab.isWaitingToReconnect)
        #expect(store.tmuxSessionNamesByHost[.ssh("devbox")] == [setup.tmuxSessionName, "justsessions-codex-other"])
        #expect(setup.host.askCount.value == 1)
    }

    @Test func aDroppedPlainTerminalIsReconnectedToItsShell() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        let store = setup.sandbox.first
        let plainTerminal = try store.makePlainTerminal(in: ProjectLocation(host: .ssh("devbox"), path: "/srv/app"))
        store.openTerminal(plainTerminal)
        let tmuxSessionName = try #require(plainTerminal.tmuxSessionName)
        setup.host.answer.update { $0 = [tmuxSessionName] }

        setup.drop(plainTerminal)
        #expect(plainTerminal.isWaitingToReconnect)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        try await expectEventually { !store.terminalSessions.contains { $0.id == plainTerminal.id } }
        let replacement = try #require(store.terminalSessions.first { $0.isPlainTerminal })
        #expect(!replacement.hasExited)
        #expect(replacement.tmuxSessionName == tmuxSessionName)
        #expect(store.selectedTerminalID == replacement.id)
    }

    @Test func aDroppedTabWhoseTmuxSessionIsGoneStaysEnded() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [] }

        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        try await expectEventually { !setup.tab.isWaitingToReconnect }
        #expect(setup.sandbox.first.terminalSessions.map(\.id) == [setup.tab.id])
        #expect(setup.tab.hasExited)
        setup.reconnector.tryAgain()
        setup.clock.advance(by: 60)
        setup.reconnector.askDueHosts()
        #expect(!setup.tab.isWaitingToReconnect)
        #expect(setup.host.askCount.value == 1)
    }

    @Test func aHostThatCantBeAskedIsAskedAgainLater() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        let store = setup.sandbox.first

        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()
        try await setup.waitForAnswer(number: 1)
        #expect(setup.tab.isWaitingToReconnect)
        setup.host.answer.update { $0 = [setup.tmuxSessionName] }
        setup.clock.advance(by: 4.9)
        setup.reconnector.askDueHosts()
        #expect(setup.host.askCount.value == 1)
        setup.clock.advance(by: 0.1)
        setup.reconnector.askDueHosts()

        try await expectEventually { store.terminalSessions.first?.id != setup.tab.id }
        #expect(store.terminalSessions.first?.hasExited == false)
    }

    @Test func aHostThatNeedsConnectIsAskedOnceItsLoginOpens() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [setup.tmuxSessionName] }
        let store = setup.sandbox.first
        store.sshHostsNeedingLogIn.insert("devbox")

        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()
        #expect(setup.host.askCount.value == 0)
        #expect(setup.tab.isWaitingToReconnect)

        store.sshHostsNeedingLogIn.remove("devbox")
        setup.reconnector.tryAgain(onlyOn: "devbox")
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        try await expectEventually { store.terminalSessions.first?.id != setup.tab.id }
    }

    /// A CLI or shell that exited, or a tmux client that detached, ends `ssh` with another status.
    @Test func onlyATabWhoseConnectionDroppedIsReconnected() throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [setup.tmuxSessionName] }

        setup.end(setup.tab, exitCode: 0)
        setup.reconnector.tryAgain()
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        #expect(!setup.tab.isWaitingToReconnect)
        #expect(setup.host.askCount.value == 0)
    }

    /// `ssh` ends with the same status when it couldn't connect or log in; a tab that ended so right after starting
    /// points at Check host instead.
    @Test func aTabThatCouldntConnectIsNotReconnected() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        let folder = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let couldntConnect = TerminalSession(
            engine: .swiftTerm,
            conversation: setup.conversation,
            provider: .claude,
            projectPath: setup.conversation.projectPath,
            action: .resume,
            displayTitle: "Couldn't connect",
            command: NativeCLICommand(
                executablePath: "/bin/sh",
                arguments: ["-c", "exit \(RemoteHostCommandRunner.connectionFailureExitStatus)"],
                workingDirectory: folder.path,
                environment: ["PATH=/usr/bin:/bin"]
            ),
            host: .ssh("devbox"),
            tmuxSessionName: "justsessions-claude-couldnt-connect"
        )
        setup.host.answer.update { $0 = ["justsessions-claude-couldnt-connect"] }
        setup.sandbox.first.openTerminal(couldntConnect)

        couldntConnect.startIfNeeded()
        setup.end(couldntConnect, exitCode: RemoteHostCommandRunner.connectionFailureExitStatus)
        setup.reconnector.tryAgain()
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        #expect(couldntConnect.exitCode == RemoteHostCommandRunner.connectionFailureExitStatus)
        #expect(couldntConnect.endedWithErrorSoonAfterStarting)
        #expect(!couldntConnect.isWaitingToReconnect)
        #expect(setup.host.askCount.value == 0)
    }

    @Test func aTabThatDropsSoonAfterReconnectingWaitsForTheNextWake() async throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [setup.tmuxSessionName] }
        let store = setup.sandbox.first
        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()
        try await expectEventually { store.terminalSessions.first?.id != setup.tab.id }
        let replacement = try #require(store.terminalSessions.first)

        setup.clock.advance(by: 30)
        setup.drop(replacement)
        #expect(!replacement.isWaitingToReconnect)

        setup.reconnector.tryAgain()
        #expect(replacement.isWaitingToReconnect)
    }

    @Test func aDroppedTabOnADisconnectedHostIsGivenUp() throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        setup.host.answer.update { $0 = [setup.tmuxSessionName] }
        for store in [setup.sandbox.first, setup.sandbox.second] {
            store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        }

        setup.drop(setup.tab)
        setup.clock.advance(by: 2)
        setup.reconnector.askDueHosts()

        #expect(setup.host.askCount.value == 0)
        #expect(!setup.tab.isWaitingToReconnect)
    }

    @Test func aTabEndedByClosingTheLoginIsNotReconnected() throws {
        let setup = try DroppedTabSetup()
        defer { setup.tearDown() }
        let loginDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: loginDirectory) }
        let connections = SSHLoginConnections(close: { _, _ in })
        FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: loginDirectory), contents: nil)
        connections.add(loginDirectory, for: "devbox")
        let store = setup.sandbox.first
        let throughLogin = TerminalSession(
            engine: .swiftTerm,
            conversation: setup.conversation,
            provider: .claude,
            projectPath: setup.conversation.projectPath,
            action: .resume,
            displayTitle: "Through the login",
            command: RemoteCLICommandBuilder(inheritedEnvironment: [:], loginConnections: connections)
                .sshCommand(host: "devbox", remoteCommand: "true"),
            host: .ssh("devbox"),
            tmuxSessionName: "justsessions-claude-through-login"
        )
        store.openTerminal(throughLogin)
        for window in [setup.sandbox.first, setup.sandbox.second] { window.remoteHostList = RemoteHostList(hosts: []) }

        store.closeLogin(on: "devbox", connections: connections)
        setup.drop(throughLogin)
        setup.drop(setup.tab)

        #expect(throughLogin.connectionEndedOnPurpose)
        #expect(!throughLogin.isWaitingToReconnect)
        #expect(!setup.tab.connectionEndedOnPurpose)
        #expect(setup.tab.isWaitingToReconnect)
    }
}

@MainActor
private struct DroppedTabSetup {
    let sandbox: TwoWindowSandbox
    let conversation: Conversation
    let tab: TerminalSession
    let host = MadeUpHost()
    let clock = TestClock()
    let reconnector: RemoteTabReconnector

    var tmuxSessionName: String { TmuxSessionName.forConversation(conversation) }

    init() throws {
        sandbox = try TwoWindowSandbox()
        conversation = sandbox.listSSHSession()
        for store in [sandbox.first, sandbox.second] { store.remoteHostList = RemoteHostList(hosts: ["devbox"]) }
        tab = try #require(sandbox.openTab(of: conversation, in: sandbox.first))
        let clock = clock
        reconnector = RemoteTabReconnector(
            registry: sandbox.windowRegistry,
            listTmuxSessions: host.listTmuxSessions,
            currentDate: { clock.now },
            wakesItselfUp: false
        )
    }

    func drop(_ tab: TerminalSession) {
        end(tab, exitCode: RemoteHostCommandRunner.connectionFailureExitStatus)
    }

    func end(_ tab: TerminalSession, exitCode: Int32) {
        tab.onProcessFinished = nil
        tab.processFinished(exitCode: exitCode)
        reconnector.tabDropped(tab)
    }

    func waitForAnswer(number: Int) async throws {
        try await expectEventually { host.askCount.value == number && !reconnector.isAsking("devbox") }
    }

    func tearDown() {
        sandbox.tearDown()
    }
}

private final class MadeUpHost: Sendable {
    let answer = LockedValue<Set<String>?>(nil)
    let askCount = LockedValue(0)

    var listTmuxSessions: @Sendable (String) -> Set<String>? {
        { [answer, askCount] _ in
            askCount.update { $0 += 1 }
            return answer.value
        }
    }
}

@MainActor
private final class TestClock {
    private(set) var now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func advance(by seconds: TimeInterval) {
        now += seconds
    }
}
