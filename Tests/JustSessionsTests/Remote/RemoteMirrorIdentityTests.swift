import Foundation
import Testing

@testable import JustSessions

struct RemoteMirrorIdentityTests {
    @Test func punctuationAndCaseCollisionsKeepIndependentCopiesAndRemoval() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = RemoteSessionMirror(cacheRoot: root)
        let hosts = ["dev+gpu", "dev_gpu", "DEVBOX", "devbox"]
        for host in hosts {
            let directory = mirror.mirrorDirectory(host: host, provider: .pi)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try host.write(to: directory.appendingPathComponent("owner"), atomically: true, encoding: .utf8)
        }
        mirror.removeMirror(host: "dev+gpu")
        for host in hosts.dropFirst() {
            let owner = mirror.mirrorDirectory(host: host, provider: .pi).appendingPathComponent("owner")
            #expect(try String(contentsOf: owner, encoding: .utf8) == host)
        }
    }

    @Test @MainActor func aDisconnectedHostListsItsCopyWithoutConnecting() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let mirror = RemoteSessionMirror(cacheRoot: root, hostAccess: .standIn(home: root.path))
        let project = mirror.mirrorDirectory(host: "devbox", provider: .claude).appendingPathComponent("projects/-srv-project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        try #"{"type":"user","cwd":"/srv/project","message":{"content":"Cached history"}}"#.appending("\n")
            .write(to: project.appendingPathComponent("\(id).jsonl"), atomically: true, encoding: .utf8)
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        store.remoteSessionDiscovery = RemoteSessionDiscovery(mirror: mirror)

        store.listRemoteHostFromMirror("devbox")

        try await expectEventually { store.conversations.contains { $0.sessionID == id } }
        #expect(store.isDisconnected("devbox"))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
        #expect(
            store.conversations.first?.sourceFile.resolvingSymlinksInPath().path
                .hasPrefix(mirror.mirrorDirectory(host: "devbox", provider: .claude).resolvingSymlinksInPath().path + "/") == true)
    }
}
