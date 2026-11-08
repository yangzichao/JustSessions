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

    @Test func aUniqueSafeLegacyCopyAndItsToolFoldersArePreserved() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = RemoteSessionMirror(cacheRoot: root)
        let legacy = root.appendingPathComponent("devbox")
        try FileManager.default.createDirectory(at: legacy.appendingPathComponent("pi"), withIntermediateDirectories: true)
        let folders = RemoteToolFolders(claude: "/private/claude", codex: "/private/codex", kiro: "/private/kiro/sessions/cli", pi: "/private/pi")
        try JSONEncoder().encode(folders).write(to: legacy.appendingPathComponent("tool-folders.json"))
        try "kept".write(to: legacy.appendingPathComponent("pi/owner"), atomically: true, encoding: .utf8)

        mirror.migrateLegacyMirrors(for: ["devbox"])
        mirror.migrateLegacyMirrors(for: ["devbox"])

        #expect(mirror.savedToolFolders(host: "devbox") == folders)
        #expect(try String(contentsOf: mirror.mirrorDirectory(host: "devbox", provider: .pi).appendingPathComponent("owner"), encoding: .utf8) == "kept")
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test(arguments: [["dev+gpu", "dev_gpu"], ["DEVBOX", "devbox"], ["dev+gpu"]])
    func anAmbiguousOrSanitizedLegacyCopyIsNotAssigned(_ hosts: [String]) throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = RemoteSessionMirror(cacheRoot: root)
        let legacy = root.appendingPathComponent(RemoteSessionMirror.legacyDirectoryName(forHost: hosts[0]))
        try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
        try "unknown owner".write(to: legacy.appendingPathComponent("owner"), atomically: true, encoding: .utf8)

        mirror.migrateLegacyMirrors(for: hosts)
        for host in hosts { mirror.removeMirror(host: host) }

        #expect(try String(contentsOf: legacy.appendingPathComponent("owner"), encoding: .utf8) == "unknown owner")
        #expect(hosts.allSatisfy { !FileManager.default.fileExists(atPath: mirror.mirrorDirectory(host: $0, provider: .pi).path) })
    }

    @Test @MainActor func aDisconnectedHostListsItsMigratedCopyWithoutConnecting() async throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let settings = try IsolatedUserDefaults()
        defer { settings.removeSuite() }
        let project = root.appendingPathComponent("devbox/claude/projects/-srv-project")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        try #"{"type":"user","cwd":"/srv/project","message":{"content":"Cached history"}}"#.appending("\n")
            .write(to: project.appendingPathComponent("\(id).jsonl"), atomically: true, encoding: .utf8)
        let mirror = RemoteSessionMirror(cacheRoot: root, sourceHomeOverride: root.path)
        let store = ConversationStore(adapters: [], userDefaults: settings.userDefaults, startsBackgroundPolling: false)
        store.remoteHostList = RemoteHostList(hosts: ["devbox"])
        store.disconnectedRemoteHosts.setDisconnected(true, for: "devbox")
        store.remoteSessionDiscovery = RemoteSessionDiscovery(mirror: mirror)

        store.listRemoteHostFromMirror("devbox")

        try await expectEventually { store.conversations.contains { $0.sessionID == id } }
        #expect(store.isDisconnected("devbox"))
        #expect(store.hostRefreshStatuses[.ssh("devbox")] == nil)
        #expect(store.conversations.first?.sourceFile.resolvingSymlinksInPath().path
            .hasPrefix(mirror.mirrorDirectory(host: "devbox", provider: .claude).resolvingSymlinksInPath().path + "/") == true)
    }
}
