import Foundation
import Testing

@testable import JustSessions

/// A Codex session waiting for your approval gets the same waiting mark, Waiting for you, and notification as Claude
/// Code's. Each test runs the app's own launch, tmux, activity sync, and sidebar filtering against a stand-in Codex
/// and a stand-in of its background server; see `UnseenTurnSandboxApp`.
@MainActor
struct CodexApprovalActivityEndToEndTests {
    @Test func aCodexCommandWaitingForApprovalWaitsForYouUntilYouAllowIt() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try app.startCodexAppServer()
        try await app.saveSession("Clean the build", of: .codex)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Clean the build")
        try await app.sendPrompt("Remove the build folder", in: "Clean the build")
        try app.codexAppServerSaysWorking(in: "Clean the build")
        try await app.resume("Check the references")

        try await app.codexAsksForApproval(in: "Clean the build")
        #expect(try app.rowStatus(of: "Clean the build") == .running(.needsInput(reason: nil)))
        #expect(app.waitingForYou.titles == ["Clean the build"])
        #expect(app.notifications.map(\.reason) == [.needsInput(reason: nil)])

        try app.select("Clean the build")
        try await app.allowCodexCommand(in: "Clean the build")
        #expect(try app.rowStatus(of: "Clean the build") == .running(.working))
        #expect(app.waitingForYou.titles.isEmpty)
        try await app.finishTurn(of: "Clean the build")
        // You watched it finish.
        #expect(try app.rowStatus(of: "Clean the build") == .running(.idle))
    }

    @Test func aCodexWhoseThreadTheServerDoesNotHoldWorksThroughItsTurn() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        let server = try app.startCodexAppServer()
        try await app.saveSession("Clean the build", of: .codex)
        try await app.resume("Clean the build")
        try await app.sendPrompt("Remove the build folder", in: "Clean the build")
        // Started with --no-daemon, Codex runs this thread itself; the server holds another one.
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: UUID().uuidString.lowercased())

        await app.followCLIsOnce()
        await app.followCLIsOnce()
        #expect(try app.rowStatus(of: "Clean the build") == .running(.working))
        #expect(server.methods.contains("thread/loaded/list"))
    }
}
