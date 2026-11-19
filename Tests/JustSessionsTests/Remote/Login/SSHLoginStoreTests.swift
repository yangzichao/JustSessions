import Foundation
import Testing

@testable import JustSessions

/// A host that asks for a password or a code offers Connect… on its heading, and a login opened from any window
/// refreshes the host in every window.
struct SSHLoginStoreTests {
    @Test @MainActor func aRefusedLoginOffersConnect() {
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)

        store.noteLoginState(on: "devbox", refreshProblem: .loginRefused)
        store.noteLoginState(on: "buildbox", refreshProblem: .hostKeyNotTrusted)
        store.noteLoginState(on: "offline", refreshProblem: .noAnswer)

        #expect(store.sshHostsNeedingLogIn == ["devbox", "buildbox"])
    }

    @Test @MainActor func aRefreshThatWorksNoLongerOffersConnect() {
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        store.noteLoginState(on: "devbox", refreshProblem: .loginRefused)

        store.noteLoginState(on: "devbox", refreshProblem: nil)

        #expect(store.sshHostsNeedingLogIn.isEmpty)
    }

    /// The master closed on its own, as when the Mac slept, so the ⋯ menu offers Connect… again.
    @Test @MainActor func aRefreshNoticesALoginThatClosed() {
        let store = ConversationStore(adapters: [], startsBackgroundPolling: false)
        store.sshHostsLoggedIn = ["devbox"]

        store.noteLoginState(on: "devbox", refreshProblem: .loginRefused, connections: SSHLoginConnections(close: { _, _ in }))

        #expect(store.sshHostsLoggedIn.isEmpty)
        #expect(store.sshHostsNeedingLogIn == ["devbox"])
    }

    @Test @MainActor func loggingInMarksTheHostInEveryWindow() async throws {
        let scripts = try makeTemporaryDirectory()
        let socketRoot = makeShortSocketFolder()
        defer {
            try? FileManager.default.removeItem(at: scripts)
            try? FileManager.default.removeItem(atPath: socketRoot)
        }
        try writeExecutableScript(SSHLoginTests.fakeSSH, to: scripts.appendingPathComponent("ssh"))
        try writeExecutableScript(SSHLoginTests.fakeAskpass, to: scripts.appendingPathComponent("askpass"))
        let connections = SSHLoginConnections(close: { _, _ in })
        let login = SSHLogin(
            askpassProgram: scripts.appendingPathComponent("askpass").path,
            sshExecutable: scripts.appendingPathComponent("ssh").path,
            socketRoot: socketRoot,
            connections: connections,
            timeout: 120
        )
        let registry = WorkspaceWindowRegistry()
        let window = ConversationStore(adapters: [], windowRegistry: registry, startsBackgroundPolling: false)
        let otherWindow = ConversationStore(adapters: [], windowRegistry: registry, startsBackgroundPolling: false)
        window.noteLoginState(on: "devbox", refreshProblem: .loginRefused)
        otherWindow.noteLoginState(on: "devbox", refreshProblem: .loginRefused)

        let outcome = await window.logIn(to: "devbox", login: login) { _ in "hunter2" }

        #expect(outcome == .loggedIn)
        for store in [window, otherWindow] {
            #expect(store.sshHostsLoggedIn == ["devbox"])
            #expect(store.sshHostsNeedingLogIn.isEmpty)
        }
        #expect(window.sshHostsLoggingIn.isEmpty)

        window.closeLogin(on: "devbox", connections: connections)

        #expect(otherWindow.sshHostsLoggedIn.isEmpty)
        #expect(!connections.isLoggedIn("devbox"))
    }
}
