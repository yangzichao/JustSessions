import Foundation
import Testing
@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TabMovingAcrossWindowsCancellationTests {
    enum LaterChange: CaseIterable, Sendable { case disconnect, removeHost, disconnectAndConnect, closeWindow, relinkTab }

    @Test(arguments: LaterChange.allCases)
    func anObsoleteHostConfirmationCannotReopenOrMoveATab(_ change: LaterChange) async throws {
        let sandbox = try TwoWindowSandbox(remoteShellStartupCheck: RemoteShellStartupCheck(run: { _, _, _ in nil }))
        defer { sandbox.tearDown() }
        let conversation = sandbox.listSSHSession()
        let notAFolder = sandbox.root.appendingPathComponent("not-a-folder")
        try Data().write(to: notAFolder)
        for store in [sandbox.first, sandbox.second] {
            store.remoteSessionDiscovery = RemoteSessionDiscovery(mirror: RemoteSessionMirror(
                cacheRoot: notAFolder, sourceHomeOverride: sandbox.root.path
            ))
        }
        let source = try #require(sandbox.openTab(of: conversation, in: sandbox.first))
        let gate = MoveConfirmationGate()
        defer { gate.release() }
        sandbox.second.moveTerminalHere(for: conversation, remoteRunner: gate.runner)
        try await expectEventually { gate.hasStarted }

        switch change {
        case .disconnect, .disconnectAndConnect:
            sandbox.first.disconnectHost("devbox", endingTmuxSessions: false, connections: SSHLoginConnections(close: { _, _ in }))
            if change == .disconnectAndConnect { sandbox.second.connectHost("devbox") }
        case .removeHost:
            sandbox.second.removeRemoteHost("devbox", mirror: RemoteSessionMirror(cacheRoot: sandbox.root.appendingPathComponent("mirror")))
        case .closeWindow:
            sandbox.second.closeWorkspace()
        case .relinkTab:
            let other = Conversation.fixture(projectPath: "/srv/other", host: .ssh("devbox"))
            source.synchronize(conversation: other, displayTitle: "Other")
        }
        gate.release()
        try await expectEventually { gate.hasReturned }
        // The confirmation schedules its result on the main actor after the injected runner returns.
        for _ in 0..<10 { await Task.yield() }
        try await Task.sleep(for: .milliseconds(100))

        #expect(sandbox.second.terminalSessions.isEmpty)
        #expect(sandbox.second.errorMessage == nil)
        if change == .disconnect {
            #expect(sandbox.first.isDisconnected("devbox"))
            #expect(sandbox.second.isDisconnected("devbox"))
        }
        if change == .removeHost {
            #expect(!sandbox.second.remoteHostList.hosts.contains("devbox"))
            #expect(sandbox.second.conversation(withID: conversation.id) == nil)
        }
        if change == .relinkTab {
            #expect(sandbox.first.terminalSessions.map(\.id) == [source.id])
            #expect(source.displayTitle == "Other")
        }
        try await expectEventually {
            [sandbox.first, sandbox.second].allSatisfy { $0.hostRefreshStatuses[.ssh("devbox")] != .refreshing }
        }
    }
}

private final class MoveConfirmationGate: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var started = false
    private var returned = false
    var hasStarted: Bool { lock.withLock { started } }
    var hasReturned: Bool { lock.withLock { returned } }
    var runner: RemoteHostCommandRunner {
        RemoteHostCommandRunner(run: { [self] _, _, _ in
            lock.withLock { started = true }
            _ = semaphore.wait(timeout: .now() + 10)
            lock.withLock { returned = true }
            return (0, "")
        })
    }
    func release() { semaphore.signal() }
}
