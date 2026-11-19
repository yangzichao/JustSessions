import Foundation
import Testing

@testable import JustSessions

/// Codex tells when it waits for your approval only through its shared background server, which holds the thread of
/// each Codex CLI that runs on it. Here the test plays the server's part for the stand-in Codex.
extension UnseenTurnSandboxApp {
    /// Starts the server where Codex keeps its socket in the sandbox's home, and has the app ask it.
    @discardableResult
    func startCodexAppServer() throws -> FakeCodexAppServer {
        let codexDirectory = sandbox.root.appendingPathComponent(".codex")
        let server = try FakeCodexAppServer(socketPath: sandbox.root.appendingPathComponent("cx.sock").path, linkedFrom: codexDirectory)
        codexAppServer = server
        store.codexWaitReader = CodexAppServerWaitReader(codexDirectory: codexDirectory, clientVersion: "test")
        return server
    }

    /// The server says the session's thread is in a turn, as it does once Codex starts one.
    func codexAppServerSaysWorking(in title: String) throws {
        try #require(codexAppServer).setStatus(FakeCodexAppServer.working, ofThread: try conversation(title).sessionID)
    }

    /// Codex asks for approval of a command in the middle of its turn, and the activity sync sees it.
    func codexAsksForApproval(in title: String) async throws {
        try #require(codexAppServer).setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: try conversation(title).sessionID)
        let isWaiting = { [self] () -> Bool in
            if case .needsInput = activity(of: title) { return true }
            return false
        }
        try #require(await followCLIs(until: isWaiting), "\"\(title)\" never waited for approval")
    }

    /// You allow the command, Codex runs it in the same turn, and the activity sync sees it.
    func allowCodexCommand(in title: String) async throws {
        try codexAppServerSaysWorking(in: title)
        let isWorking = { [self] in activity(of: title) == .working }
        try #require(await followCLIs(until: isWorking), "\"\(title)\" never went back to work")
    }
}
