import Foundation
import Testing

@testable import JustSessions

@Suite(.oneHeldThreadAtATime)
@MainActor
struct DeletionRefreshTests {
    @Test func onlyTheSSHHostTheDeletionDeletesFromWaitsToRefresh() async throws {
        let sandbox = try DeletionSandbox()
        defer { sandbox.remove() }
        let onDevbox = try sandbox.savedConversation(onHost: "devbox")
        let onBuildbox = try sandbox.savedConversation(onHost: "buildbox")
        let hosts = SimulatedSSHHosts(holdingAttempt: 1) { _, _ in SimulatedSSHHosts.deleted }
        let store = sandbox.makeStore(listing: [onDevbox, onBuildbox], remoteDeletion: hosts.deletion)
        let discovery = try Self.discoveryThatFailsWithoutSSH(in: sandbox)

        store.deleteConversations([onDevbox])
        try await expectEventually { hosts.totalAttempts == 1 }
        store.refreshRemoteHost("devbox", discovery: discovery)
        store.refreshRemoteHost("buildbox", discovery: discovery)
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
        #expect(store.hostRefreshStatuses[.ssh("buildbox")] == .refreshing)

        store.remoteHostList = RemoteHostList(hosts: ["buildbox"])
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }
        #expect(!store.deferRefreshWhileDeleting(on: .ssh("devbox")))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
    }

    private static func discoveryThatFailsWithoutSSH(in sandbox: DeletionSandbox) throws -> RemoteSessionDiscovery {
        let notAFolder = sandbox.directory.appendingPathComponent("not-a-folder")
        try "".write(to: notAFolder, atomically: true, encoding: .utf8)
        return RemoteSessionDiscovery(
            mirror: RemoteSessionMirror(cacheRoot: notAFolder, hostAccess: .standIn(home: sandbox.directory.path)))
    }
}
