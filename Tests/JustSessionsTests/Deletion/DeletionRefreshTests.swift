import Foundation
import Testing
@testable import JustSessions

/// A refresh of an SSH host asked for while a deletion runs on it waits until the deletion ends; a refresh of
/// another host does not wait. That the waiting refresh then runs is checked only for this Mac, in
/// `DeletionDuringRefreshTests`: for an SSH host it would copy the host over `ssh`.
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

        // The deferred refresh copies the host with the default mirror, which would run `ssh`; leaving devbox off
        // the host list makes it stop there, so this checks only that the deferral is cleared, not that it runs.
        store.remoteHostList = RemoteHostList(hosts: ["buildbox"])
        hosts.releaseHeldAttempt()
        try await expectEventually { !store.isDeletingSessions }
        #expect(!store.deferRefreshWhileDeleting(on: .ssh("devbox")))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
    }

    /// Its mirror would go inside a regular file, so the copy fails before any `rsync` or `ssh` runs.
    private static func discoveryThatFailsWithoutSSH(in sandbox: DeletionSandbox) throws -> RemoteSessionDiscovery {
        let notAFolder = sandbox.directory.appendingPathComponent("not-a-folder")
        try "".write(to: notAFolder, atomically: true, encoding: .utf8)
        return RemoteSessionDiscovery(mirror: RemoteSessionMirror(cacheRoot: notAFolder, sourceHomeOverride: sandbox.directory.path))
    }
}
