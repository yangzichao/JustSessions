import Foundation
import Testing

@testable import JustSessions

struct SSHLoginConnectionsTests {
    @Test func aHostWithoutALoginConnectsAsBefore() {
        #expect(SSHLoginConnections(close: { _, _ in }).connectionOptions(for: "devbox").isEmpty)
    }

    @Test func connectionsGoThroughTheHostsOpenLogin() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let connections = SSHLoginConnections(close: { _, _ in })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)

        connections.add(directory, for: "devbox")

        #expect(connections.connectionOptions(for: "devbox") == ["-o", "ControlMaster=no", "-o", "ControlPath=\(controlPath)"])
        #expect(connections.connectionOptions(for: "buildbox").isEmpty)
        #expect(connections.loggedInHosts == ["devbox"])
    }

    /// A master that ends, as after the Mac sleeps, removes its socket.
    @Test func aLoginThatEndedIsNoLongerUsed() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let connections = SSHLoginConnections(close: { _, _ in })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)
        connections.add(directory, for: "devbox")

        try FileManager.default.removeItem(atPath: controlPath)

        #expect(!connections.isLoggedIn("devbox"))
        #expect(connections.connectionOptions(for: "devbox").isEmpty)
    }

    @Test func anEndedLoginIsForgottenWithItsFolder() throws {
        let ended = try makeTemporaryDirectory()
        let open = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: open) }
        let connections = SSHLoginConnections(close: { _, _ in })
        connections.add(ended, for: "devbox")
        FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: open), contents: nil)
        connections.add(open, for: "buildbox")

        connections.forgetEndedLogin(of: "devbox")
        connections.forgetEndedLogin(of: "buildbox")

        #expect(!FileManager.default.fileExists(atPath: ended.path))
        #expect(connections.loggedInHosts == ["buildbox"])
    }

    @Test func disconnectingClosesTheMasterAndItsFolder() async throws {
        let directory = try makeTemporaryDirectory()
        let closed = LockedValue<[String]>([])
        let connections = SSHLoginConnections(close: { host, controlPath in closed.update { $0.append("\(host) \(controlPath)") } })
        let controlPath = SSHLoginConnections.controlPath(in: directory)
        FileManager.default.createFile(atPath: controlPath, contents: nil)
        connections.add(directory, for: "devbox")

        connections.disconnect("devbox")

        #expect(!connections.isLoggedIn("devbox"))
        try await expectEventually { !FileManager.default.fileExists(atPath: directory.path) }
        #expect(closed.value == ["devbox \(controlPath)"])
    }

    @Test func aNewLoginReplacesTheHostsEarlierOne() async throws {
        let earlier = try makeTemporaryDirectory()
        let later = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: later) }
        let closed = LockedValue<[String]>([])
        let connections = SSHLoginConnections(close: { _, controlPath in closed.update { $0.append(controlPath) } })
        for directory in [earlier, later] {
            FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: directory), contents: nil)
        }

        connections.add(earlier, for: "devbox")
        connections.add(later, for: "devbox")

        #expect(connections.connectionOptions(for: "devbox").last == "ControlPath=\(SSHLoginConnections.controlPath(in: later))")
        try await expectEventually { closed.value == [SSHLoginConnections.controlPath(in: earlier)] }
    }

    @Test func quittingClosesEveryLoginBeforeItReturns() throws {
        let closed = LockedValue<Set<String>>([])
        let connections = SSHLoginConnections(close: { host, _ in closed.update { $0.insert(host) } })
        var directories: [URL] = []
        for host in ["devbox", "buildbox"] {
            let directory = try makeTemporaryDirectory()
            directories.append(directory)
            FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: directory), contents: nil)
            connections.add(directory, for: host)
        }

        connections.disconnectAll()

        #expect(closed.value == ["devbox", "buildbox"])
        #expect(directories.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(connections.loggedInHosts.isEmpty)
    }
}
