import Darwin
import Foundation
import Testing

@testable import JustSessions

struct SSHConnectionSharingTests {
    @Test func usesOnePrivateSocketForARefresh() {
        #expect(
            SSHConnectionSharing.options(controlPath: "/tmp/justsessions-ssh-501/refresh-id/master") == [
                "-o", "ControlMaster=auto",
                "-o", "ControlPath=/tmp/justsessions-ssh-501/refresh-id/master",
                "-o", "ControlPersist=60",
            ])
    }

    /// `%C` is not used in the app-owned path, but `ssh` still adds 17 characters while it sets the socket up; a
    /// Unix socket's path must fit in 104 bytes, its ending NUL included.
    @Test func theSocketPathFitsAUnixSocket() {
        let longestPath = SSHConnectionSharing.socketRoot + "/refresh-" + UUID().uuidString + "/master." + String(repeating: "x", count: 16)

        #expect(longestPath.utf8.count < 104)
        #expect(SSHConnectionSharing.socketRoot == "/tmp/justsessions-ssh-\(getuid())")
    }

    /// A host logged in to with Connect… refreshes through that login, and the refresh leaves it open.
    @Test func aRefreshGoesThroughTheHostsLogin() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let closed = LockedValue(0)
        let connections = SSHLoginConnections(close: { _, _ in closed.update { $0 += 1 } })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)
        connections.add(directory, for: "devbox")

        let sharing = try #require(SSHConnectionSharing.startRefresh(to: "devbox", loginConnections: connections))
        sharing.finish()

        #expect(sharing.options == ["-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)"])
        #expect(closed.value == 0)
        #expect(connections.isLoggedIn("devbox"))
    }

    @Test func createsASeparatePrivateFolderForEveryRefresh() throws {
        let root = try makeTemporaryDirectory().appendingPathComponent("sockets").path
        defer { try? FileManager.default.removeItem(atPath: root) }

        let first = try #require(
            SSHSocketDirectory.makeRefreshDirectory(
                at: root,
                identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            ))
        let second = try #require(
            SSHSocketDirectory.makeRefreshDirectory(
                at: root,
                identifier: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            ))

        #expect(first != second)
        let rootPermissions = try FileManager.default.attributesOfItem(atPath: root)[.posixPermissions] as? Int
        let refreshPermissions = try FileManager.default.attributesOfItem(atPath: first.path)[.posixPermissions] as? Int
        #expect(rootPermissions == 0o700)
        #expect(refreshPermissions == 0o700)
    }

    @Test func refusesARootOthersCanEnter() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("sockets").path
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])

        #expect(SSHSocketDirectory.makeRefreshDirectory(at: folder) == nil)
    }

    @Test func refusesALinkInPlaceOfTheRoot() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("elsewhere").path
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let link = root.appendingPathComponent("sockets").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)

        #expect(SSHSocketDirectory.makeRefreshDirectory(at: link) == nil)
    }

    @Test func teardownEndsOnlyItsOwnMasterRemovesItsFolderAndIsIdempotent() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("refresh")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let controlPath = directory.appendingPathComponent("master").path
        try Data().write(to: URL(fileURLWithPath: controlPath))
        let closes = CloseRecorder()
        let sharing = SSHConnectionSharing(host: "alias", directory: directory, controlPath: controlPath) { host, path in
            closes.append(host: host, path: path)
        }

        sharing.finish()
        sharing.finish()

        #expect(closes.values.count == 1)
        #expect(closes.values.first?.0 == "alias")
        #expect(closes.values.first?.1 == controlPath)
        #expect(!FileManager.default.fileExists(atPath: directory.path))
    }
}

private final class CloseRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [(String, String)] = []

    var values: [(String, String)] {
        lock.withLock { stored }
    }

    func append(host: String, path: String) {
        lock.withLock { stored.append((host, path)) }
    }
}
