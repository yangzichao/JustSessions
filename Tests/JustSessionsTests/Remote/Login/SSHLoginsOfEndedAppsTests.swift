import Foundation
import Testing

@testable import JustSessions

struct SSHLoginsOfEndedAppsTests {
    @Test func onlyLoginsOfAppsNoLongerRunningAreClosed() throws {
        let root = makeShortSocketFolder()
        defer { try? FileManager.default.removeItem(atPath: root) }
        let ours = try #require(SSHSocketDirectory.makeLoginDirectory(at: root))
        let anotherRunningApp = try #require(SSHSocketDirectory.makeLoginDirectory(at: root, processID: getppid()))
        let crashed = try #require(SSHSocketDirectory.makeLoginDirectory(at: root, processID: try Self.endedProcessID()))
        let refresh = try #require(SSHSocketDirectory.makeRefreshDirectory(at: root))
        for directory in [ours, anotherRunningApp, crashed, refresh] {
            FileManager.default.createFile(atPath: SSHLoginConnections.controlPath(in: directory), contents: nil)
        }
        let closed = LockedValue<[String]>([])

        SSHLoginConnections.closeLoginsOfEndedApps(
            socketRoot: root,
            close: { _, controlPath in
                closed.update { $0.append(controlPath) }
            })

        #expect(closed.value == [SSHLoginConnections.controlPath(in: crashed)])
        #expect(!FileManager.default.fileExists(atPath: crashed.path))
        for directory in [ours, anotherRunningApp, refresh] {
            #expect(FileManager.default.fileExists(atPath: directory.path))
        }
    }

    @Test func aFolderNamedOtherwiseIsLeftAlone() throws {
        let root = makeShortSocketFolder()
        defer { try? FileManager.default.removeItem(atPath: root) }
        _ = try #require(SSHSocketDirectory.preparedRoot(at: root))
        let digitsFirst = URL(fileURLWithPath: root).appendingPathComponent("login-12345678-1234-4234-8234-123456789012")
        try FileManager.default.createDirectory(at: digitsFirst, withIntermediateDirectories: false)

        #expect(SSHSocketDirectory.loginDirectoriesOfEndedProcesses(at: root, isRunning: { _ in false }).isEmpty)
    }

    private static func endedProcessID() throws -> pid_t {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }
}
