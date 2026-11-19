import Foundation
import Testing

@testable import JustSessions

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
        #expect(try app.rowStatus(of: "Clean the build") == .running(.idle))
    }

    @Test func aCodexWhoseThreadTheServerDoesNotHoldWorksThroughItsTurn() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        let server = try app.startCodexAppServer()
        try await app.saveSession("Clean the build", of: .codex)
        try await app.resume("Clean the build")
        try await app.sendPrompt("Remove the build folder", in: "Clean the build")
        server.setStatus(FakeCodexAppServer.waitingOnApproval, ofThread: UUID().uuidString.lowercased())

        await app.followCLIsOnce()
        await app.followCLIsOnce()
        #expect(try app.rowStatus(of: "Clean the build") == .running(.working))
        #expect(server.methods.contains("thread/loaded/list"))
    }
}
