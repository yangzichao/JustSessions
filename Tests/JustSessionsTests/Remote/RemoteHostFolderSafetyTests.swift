import Foundation
import Testing
@testable import JustSessions

/// Removing an SSH host removes its mirror folder. A host named `.` or `..` used to stand for the mirrors' folder
/// or its parent, so removing it removed every mirror, or the app's whole cache folder.
struct RemoteHostFolderSafetyTests {
    @Test(arguments: [".", "..", "...", "  ..  ", ""])
    func hostsOfDotsAloneAreNotAdded(_ proposedHost: String) {
        var hostList = RemoteHostList()
        let wasAdded = hostList.add(proposedHost)
        #expect(RemoteHostList.normalizedHost(proposedHost) == nil)
        #expect(!wasAdded)
        #expect(hostList.hosts.isEmpty)
    }

    @Test(arguments: ["devbox", "me@devbox.local", "10.0.0.2", "a..b", "trailing.", ".leading-dot"])
    func otherHostsWithDotsAreStillAdded(_ host: String) {
        var hostList = RemoteHostList()
        let wasAdded = hostList.add(host)
        #expect(RemoteHostList.normalizedHost(host) == host)
        #expect(wasAdded)
        #expect(hostList.hosts == [host])
    }

    @Test(arguments: [".", "..", "...", "", "../..", "../../etc", "a/b", "~", "~/..", "*", "host name", "..\u{0}", "\u{0}", "%2e%2e"])
    func everyHostGetsAFolderOfItsOwnInsideTheCache(_ host: String) {
        expectFolderStaysInsideCache(forHost: host)
    }

    @Test func randomHostNamesNeverLeaveTheCache() {
        let alphabet: [Character] = [".", ".", ".", "/", "a", "-", "_", "@", " ", "~", "\\", "é", "\n", "*", ":"]
        var generator = SeededRandomNumberGenerator(seed: 0x5EED_F01D)
        for _ in 0..<2_000 {
            expectFolderStaysInsideCache(forHost: generator.string(of: alphabet, lengthIn: 0...6))
        }
    }

    @Test func removingAHostOfDotsLeavesEveryOtherFolderAlone() throws {
        let cachesDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cachesDirectory) }
        let mirror = RemoteSessionMirror(cacheRoot: cachesDirectory.appendingPathComponent("RemoteHosts"))
        let otherHostMirror = mirror.mirrorDirectory(host: "devbox", provider: .claude)
        try FileManager.default.createDirectory(at: otherHostMirror, withIntermediateDirectories: true)
        let unrelatedCacheFile = cachesDirectory.appendingPathComponent("unrelated.txt")
        try "keep".write(to: unrelatedCacheFile, atomically: true, encoding: .utf8)

        for host in [".", "..", "", "./.", "../.."] {
            mirror.removeMirror(host: host)
        }

        #expect(FileManager.default.fileExists(atPath: otherHostMirror.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedCacheFile.path))
    }

    @Test func removingAHostRemovesOnlyItsOwnMirror() throws {
        let cacheRoot = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let mirror = RemoteSessionMirror(cacheRoot: cacheRoot)
        let removedHostMirror = mirror.mirrorDirectory(host: "devbox", provider: .codex)
        let keptHostMirror = mirror.mirrorDirectory(host: "buildbox", provider: .codex)
        for folder in [removedHostMirror, keptHostMirror] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        mirror.removeMirror(host: "devbox")

        #expect(!FileManager.default.fileExists(atPath: removedHostMirror.deletingLastPathComponent().path))
        #expect(FileManager.default.fileExists(atPath: keptHostMirror.path))
    }

    private func expectFolderStaysInsideCache(forHost host: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let cacheRoot = URL(fileURLWithPath: "/tmp/justsessions-tests/RemoteHosts")
        let folderName = RemoteSessionMirror.directoryName(forHost: host)
        let hostFolder = cacheRoot.appendingPathComponent(folderName).standardizedFileURL

        #expect(!folderName.isEmpty, "host \(host.debugDescription)", sourceLocation: sourceLocation)
        #expect(!folderName.contains("/"), "host \(host.debugDescription)", sourceLocation: sourceLocation)
        #expect(
            hostFolder.deletingLastPathComponent().path == cacheRoot.path,
            "host \(host.debugDescription) → \(hostFolder.path)",
            sourceLocation: sourceLocation
        )
    }
}
