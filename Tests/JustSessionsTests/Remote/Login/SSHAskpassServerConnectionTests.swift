import Darwin
import Foundation
import SwiftTerm
import Testing
@testable import JustSessions

/// How the askpass server takes a helper's connection: on a busy app, with tabs starting, and after the helper has gone.
struct SSHAskpassServerConnectionTests {
    /// A full test run keeps every one of Swift's shared threads busy for minutes. Work on a global dispatch queue
    /// then waits for them all to finish, and so did a question served there.
    @Test func aQuestionArrivesWhileBusyTasksFillSwiftsSharedThreads() async throws {
        let folder = makeShortSocketFolder()
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let clock = ContinuousClock()
        let askedAt = LockedValue<ContinuousClock.Instant?>(nil)
        let server = try #require(SSHAskpassServer(socketPath: folder + "/askpass") { _ in
            askedAt.update { $0 = clock.now }
            return SSHAskpassReply(answer: nil)
        })
        defer { server.stop() }

        let busyUntil = clock.now + .seconds(1.5)
        let busyTasks = (0..<ProcessInfo.processInfo.activeProcessorCount).map { _ in
            Task.detached(priority: .high) {
                var value: UInt64 = 1
                while clock.now < busyUntil {
                    for _ in 0..<20_000 { value = value &* 6364136223846793005 &+ 1 }
                    await Task.yield()
                }
                return value
            }
        }
        let helper = try UnixStreamSocket(connectingTo: server.socketPath, timeout: .seconds(5))
        defer { helper.close() }
        let sentAt = clock.now
        try helper.write(try #require(SSHAskpassMessageLine.encoded(SSHAskpassRequest(prompt: "Password:", hint: nil))))
        try await expectEventually { askedAt.value != nil }
        for task in busyTasks { _ = await task.value }

        let asked = try #require(askedAt.value)
        let milliseconds = { (duration: Duration) in duration.formatted(.units(allowed: [.milliseconds])) }
        #expect(asked < busyUntil, "The question arrived \(milliseconds(asked - sentAt)) after it was sent; the busy tasks ended \(milliseconds(busyUntil - sentAt)) after")
    }

    /// A tab's process starts with a copy of each descriptor the app has open that isn't closed on exec, and keeps it
    /// until it ends. In a full test run, stand-in CLIs that other tests started kept a closed helper's connection open,
    /// and its question was withdrawn only when they ended, over a minute later.
    @Test func aHelperThatGoesAwayIsSeenWhileATabStartedMeanwhileRuns() async throws {
        let folder = makeShortSocketFolder()
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let isAsked = LockedValue(false)
        let isWithdrawn = LockedValue(false)
        let server = try #require(SSHAskpassServer(socketPath: folder + "/askpass") { _ in
            isAsked.update { $0 = true }
            try? await Task.sleep(for: .seconds(600)) // Ended only by a cancel.
            isWithdrawn.update { $0 = Task.isCancelled }
            return SSHAskpassReply(answer: nil)
        })
        defer { server.stop() }
        let helper = try UnixStreamSocket(connectingTo: server.socketPath, timeout: .seconds(5))
        try helper.write(try #require(SSHAskpassMessageLine.encoded(SSHAskpassRequest(prompt: "Confirm user presence", hint: "none"))))
        try await expectEventually { isAsked.value }

        var windowSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)
        let tab = try #require(PseudoTerminalHelpers.fork(andExec: "/bin/sleep", args: ["sleep", "600"], env: [], desiredWindowSize: &windowSize))
        defer {
            kill(tab.pid, SIGKILL)
            var status: Int32 = 0
            waitpid(tab.pid, &status, 0)
            close(tab.masterFd)
        }
        helper.close()

        // Long enough for a busy run; the tab's process would hold the connection for all of its 600 seconds.
        try await expectEventually(timeout: .seconds(30)) { isWithdrawn.value }
    }

    /// macOS refuses `SO_NOSIGPIPE` on a socket closed at both ends, so answering a helper that went before its
    /// connection was served would end the app with `SIGPIPE`.
    @Test(arguments: [false, true]) func aConnectionIsServedOnlyWhileItsHelperIsThere(helperHasGone: Bool) throws {
        let folder = makeShortSocketFolder()
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(atPath: folder) }
        let listener = try #require(Self.listeningSocket(at: folder + "/askpass"))
        defer { close(listener) }
        let helper = try UnixStreamSocket(connectingTo: folder + "/askpass", timeout: .seconds(5))
        try helper.write(try #require(SSHAskpassMessageLine.encoded(SSHAskpassRequest(prompt: "Password:", hint: nil))))
        if helperHasGone { helper.close() }
        defer { if !helperHasGone { helper.close() } }

        let connection = accept(listener, nil, nil)
        try #require(connection >= 0)
        defer { close(connection) }

        #expect(SSHAskpassServer.prepare(connection) == !helperHasGone)
    }

    private static func listeningSocket(at path: String) -> Int32? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8CString).map { UInt8(bitPattern: $0) }
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        let isBound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
        guard isBound, listen(descriptor, 1) == 0 else {
            close(descriptor)
            return nil
        }
        return descriptor
    }
}
