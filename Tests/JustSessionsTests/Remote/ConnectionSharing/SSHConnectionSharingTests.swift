import Darwin
import Foundation
import Testing
@testable import JustSessions

struct SSHConnectionSharingTests {
    @Test func sharesThroughASocketPerHostInTheAppsFolder() {
        #expect(SSHConnectionSharing.options(userControlPath: nil, socketDirectory: "/tmp/justsessions-ssh-501") == [
            "-o", "ControlMaster=auto",
            "-o", "ControlPath=/tmp/justsessions-ssh-501/%C",
            "-o", "ControlPersist=60",
        ])
    }

    @Test func aHostWithItsOwnControlPathKeepsTheUsersSettings() {
        #expect(SSHConnectionSharing.options(userControlPath: "/Users/me/.ssh/cm-abc", socketDirectory: "/tmp/justsessions-ssh-501").isEmpty)
    }

    @Test func withoutASafeFolderNothingIsShared() {
        #expect(SSHConnectionSharing.options(userControlPath: nil, socketDirectory: nil).isEmpty)
    }

    /// `%C` becomes 40 hex digits, and `ssh` adds 17 characters while it sets the socket up; a Unix socket's path must
    /// fit in 104 bytes, its ending NUL included.
    @Test func theSocketPathFitsAUnixSocket() {
        let longestPath = SSHConnectionSharing.socketDirectory + "/" + String(repeating: "f", count: 40) + "." + String(repeating: "x", count: 16)

        #expect(longestPath.utf8.count < 104)
        #expect(SSHConnectionSharing.socketDirectory == "/tmp/justsessions-ssh-\(getuid())")
    }

    @Test func createsAFolderOnlyItsUserCanEnter() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("sockets").path

        #expect(SSHSocketDirectory.prepared(at: folder) == folder)
        let permissions = try FileManager.default.attributesOfItem(atPath: folder)[.posixPermissions] as? Int
        #expect(permissions == 0o700)
        #expect(SSHSocketDirectory.prepared(at: folder) == folder)
    }

    @Test func refusesAFolderOthersCanEnter() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("sockets").path
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o755])

        #expect(SSHSocketDirectory.prepared(at: folder) == nil)
    }

    @Test func refusesALinkInPlaceOfTheFolder() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let target = root.appendingPathComponent("elsewhere").path
        try FileManager.default.createDirectory(atPath: target, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let link = root.appendingPathComponent("sockets").path
        try FileManager.default.createSymbolicLink(atPath: link, withDestinationPath: target)

        #expect(SSHSocketDirectory.prepared(at: link) == nil)
    }
}
