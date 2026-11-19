import Foundation
import Testing

@testable import JustSessions

/// Antigravity tells what it does in its conversation database, and its sessions then get the same dot, Waiting for
/// you, and notifications as Claude Code's. Each test runs the app's own launch, tmux, activity sync, and sidebar
/// filtering against a stand-in that writes the database as Antigravity CLI does; see `UnseenTurnSandboxApp`.
@MainActor
struct AntigravityActivityEndToEndTests {
    @Test func anAntigravityTurnThatFinishesInATabYouAreNotLookingAtKeepsADotUntilYouSelectTheTab() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Bump the version", of: .antigravity)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Bump the version")
        #expect(try app.rowStatus(of: "Bump the version") == .running(.idle))
        try await app.sendPrompt("Bump it to 1.3", in: "Bump the version")
        try await app.resume("Check the references")
        #expect(try app.rowStatus(of: "Bump the version") == .running(.working))

        try await app.finishTurn(of: "Bump the version")
        #expect(try app.rowStatus(of: "Bump the version") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Bump the version"])
        #expect(app.notifications.map(\.title) == ["Bump the version"])
        #expect(app.notifications.map(\.reason) == [.finishedTurn])

        try app.select("Bump the version")
        #expect(try app.rowStatus(of: "Bump the version") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func anAntigravityCommandWaitingForApprovalWaitsForYouUntilYouAllowIt() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Clean the build", of: .antigravity)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Clean the build")
        try await app.sendPrompt("Remove the build folder", in: "Clean the build")
        try await app.resume("Check the references")

        try await app.stopForAnswer(in: "Clean the build")
        #expect(try app.rowStatus(of: "Clean the build") == .running(.needsInput(reason: nil)))
        #expect(app.waitingForYou.titles == ["Clean the build"])
        #expect(app.notifications.map(\.reason) == [.needsInput(reason: nil)])

        try app.select("Clean the build")
        try await app.sendPrompt("1", in: "Clean the build")
        #expect(try app.rowStatus(of: "Clean the build") == .running(.working))
        #expect(app.waitingForYou.titles.isEmpty)
        try await app.finishTurn(of: "Clean the build")
        // You watched it finish.
        #expect(try app.rowStatus(of: "Clean the build") == .running(.idle))
    }
}
