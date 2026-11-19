import Foundation
import Testing

@testable import JustSessions

struct CodexAppServerWaitReaderTests {
    /// A Codex folder and a socket in a temporary folder of their own, whose path stays short enough for a socket.
    private struct Sandbox {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("cx-\(UUID().uuidString.prefix(8))")
        var codexDirectory: URL { root.appendingPathComponent(".codex") }
        var socketPath: String { root.appendingPathComponent("server.sock").path }

        func startServer() throws -> FakeCodexAppServer {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            return try FakeCodexAppServer(socketPath: socketPath, linkedFrom: codexDirectory)
        }

        func reader(retryDelay: Duration = .zero) -> CodexAppServerWaitReader {
            CodexAppServerWaitReader(
                codexDirectory: codexDirectory, clientVersion: "test", timeout: .milliseconds(300), retryDelay: retryDelay)
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }

    @Test func tellsWhichOfItsThreadsWaitOnYouReadingOnlyThoseLoaded() throws {
        let sandbox = Sandbox()
        defer { sandbox.remove() }
        let server = try sandbox.startServer()
        defer { server.stop() }
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "approval")
        server.setStatus(FakeCodexAppServer.waitingOnUserInput, ofThread: "question")
        server.setStatus(FakeCodexAppServer.working, ofThread: "working")
        server.setStatus(FakeCodexAppServer.idle, ofThread: "idle")
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "another app's")

        let waiting = sandbox.reader().threadsWaitingOnYou(among: ["approval", "question", "working", "idle", "not loaded"])

        #expect(waiting == ["approval", "question"])
        #expect(server.methods.first == "initialize")
        #expect(server.methods.filter { $0 == "thread/read" }.count == 4)
    }

    @Test func keepsOneConnectionWhileThereAreThreadsToAskAbout() async throws {
        let sandbox = Sandbox()
        defer { sandbox.remove() }
        let server = try sandbox.startServer()
        defer { server.stop() }
        server.setStatus(FakeCodexAppServer.working, ofThread: "thread")
        let reader = sandbox.reader()

        #expect(reader.threadsWaitingOnYou(among: ["thread"]).isEmpty)
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "thread")
        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])
        #expect(server.connectionCount == 1)

        #expect(reader.threadsWaitingOnYou(among: []).isEmpty)
        try await expectEventually { server.openConnections == 0 }
        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])
        #expect(server.connectionCount == 2)
    }

    @Test func aServerThatIsNotThereIsTriedAgainOnlyAfterAWhile() async throws {
        let sandbox = Sandbox()
        defer { sandbox.remove() }
        let reader = sandbox.reader(retryDelay: .seconds(1))

        #expect(reader.threadsWaitingOnYou(among: ["thread"]).isEmpty)
        let server = try sandbox.startServer()
        defer { server.stop() }
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "thread")
        #expect(reader.threadsWaitingOnYou(among: ["thread"]).isEmpty)
        #expect(server.connectionCount == 0)

        try await expectEventually { reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"] }
    }

    @Test func aServerThatStopsAnsweringCostsOneTimeoutThenReconnects() async throws {
        let sandbox = Sandbox()
        defer { sandbox.remove() }
        let server = try sandbox.startServer()
        defer { server.stop() }
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "thread")
        let reader = sandbox.reader()
        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])

        server.setAnswering(false)
        let clock = ContinuousClock()
        let started = clock.now
        #expect(reader.threadsWaitingOnYou(among: ["thread"]).isEmpty)
        #expect(clock.now - started < .seconds(2))

        server.setAnswering(true)
        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])
        #expect(server.connectionCount == 2)
    }

    @Test func aServerThatGoesAwayIsReconnectedToWhenItIsBack() throws {
        let sandbox = Sandbox()
        defer { sandbox.remove() }
        var server = try sandbox.startServer()
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "thread")
        let reader = sandbox.reader()
        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])

        server.stop()
        #expect(reader.threadsWaitingOnYou(among: ["thread"]).isEmpty)
        server = try sandbox.startServer()
        defer { server.stop() }
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: "thread")

        #expect(reader.threadsWaitingOnYou(among: ["thread"]) == ["thread"])
    }
}
