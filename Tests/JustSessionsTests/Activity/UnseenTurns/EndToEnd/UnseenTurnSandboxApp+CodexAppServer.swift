import Foundation
import Testing

@testable import JustSessions

extension UnseenTurnSandboxApp {
    @discardableResult
    func startCodexAppServer() throws -> FakeCodexAppServer {
        let codexDirectory = sandbox.root.appendingPathComponent(".codex")
        let server = try FakeCodexAppServer(socketPath: sandbox.root.appendingPathComponent("cx.sock").path, linkedFrom: codexDirectory)
        codexAppServer = server
        store.codexWaitReader = CodexAppServerWaitReader(codexDirectory: codexDirectory, clientVersion: "test")
        return server
    }

    func codexAppServerSaysWorking(in title: String) throws {
        try #require(codexAppServer).setStatus(FakeCodexAppServer.working, ofThread: try conversation(title).sessionID)
    }

    func codexAsksForApproval(in title: String) async throws {
        try #require(codexAppServer).setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: try conversation(title).sessionID)
        let isWaiting = { [self] () -> Bool in
            if case .needsInput = activity(of: title) { return true }
            return false
        }
        try #require(await followCLIs(until: isWaiting), "\"\(title)\" never waited for approval")
    }

    func allowCodexCommand(in title: String) async throws {
        try codexAppServerSaysWorking(in: title)
        let isWorking = { [self] in activity(of: title) == .working }
        try #require(await followCLIs(until: isWorking), "\"\(title)\" never went back to work")
    }
}
