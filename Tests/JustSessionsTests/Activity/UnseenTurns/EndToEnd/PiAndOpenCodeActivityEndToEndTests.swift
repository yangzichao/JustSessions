import Foundation
import Testing
@testable import JustSessions

/// Pi and OpenCode tell what they do through the extension the app starts them with, and their sessions then get the
/// same dot, Waiting for you, and notifications as Claude Code's and Codex's. Each test runs the app's own launch,
/// tmux, activity sync, and sidebar filtering against stand-ins that report only when started with the extension;
/// see `UnseenTurnSandboxApp`.
@MainActor
struct PiAndOpenCodeActivityEndToEndTests {
    @Test func aPiTurnThatFinishesInATabYouAreNotLookingAtKeepsADotUntilYouSelectTheTab() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Draft the changelog", of: .pi)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Draft the changelog")
        try await app.sendPrompt("Summarize the release", in: "Draft the changelog")
        try await app.resume("Check the references")
        #expect(try app.rowStatus(of: "Draft the changelog") == .running(.working))

        try await app.finishTurn(of: "Draft the changelog")
        #expect(try app.rowStatus(of: "Draft the changelog") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Draft the changelog"])
        #expect(app.notifications.map(\.title) == ["Draft the changelog"])
        #expect(app.notifications.map(\.reason) == [.finishedTurn])

        try app.select("Draft the changelog")
        #expect(try app.rowStatus(of: "Draft the changelog") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func aPiRunStoppedAtAnExtensionsPromptWaitsForYouUntilYouAnswer() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Clean the build", of: .pi)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Clean the build")
        try await app.sendPrompt("Remove the build folder", in: "Clean the build")
        try await app.resume("Check the references")

        try await app.stopForAnswer(in: "Clean the build")
        let waiting = SessionRunStatus.running(.needsInput(reason: StandInActivityCLI.piPromptTitle))
        #expect(try app.rowStatus(of: "Clean the build") == waiting)
        #expect(app.waitingForYou.titles == ["Clean the build"])
        #expect(app.notifications.map(\.reason) == [.needsInput(reason: StandInActivityCLI.piPromptTitle)])

        try app.select("Clean the build")
        try await app.sendPrompt("Yes", in: "Clean the build")
        #expect(try app.rowStatus(of: "Clean the build") == .running(.working))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func anOpenCodePermissionPromptWaitsForYouUntilYouAnswer() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Port the parser", of: .opencode)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Port the parser")
        try await app.sendPrompt("Port it to Swift", in: "Port the parser")
        try await app.resume("Check the references")

        try await app.stopForAnswer(in: "Port the parser")
        #expect(try app.rowStatus(of: "Port the parser") == .running(.needsInput(reason: "permission")))
        #expect(try app.projectStatus(of: "Port the parser") == .running(.needsInput(reason: nil)))
        #expect(app.waitingForYou.titles == ["Port the parser"])
        #expect(app.notifications.map(\.reason) == [.needsInput(reason: "permission")])

        try app.select("Port the parser")
        try await app.sendPrompt("Allow once", in: "Port the parser")
        try await app.finishTurn(of: "Port the parser")
        // You watched it finish.
        #expect(try app.rowStatus(of: "Port the parser") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func theDotStaysWithAnOpenCodeSessionWhoseTabClosedWithItsCLIRunningInTmux() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Port the parser", of: .opencode)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Port the parser")
        try await app.sendPrompt("Port it to Swift", in: "Port the parser")
        try await app.resume("Check the references")
        try app.closeTabKeepingItsCLIRunning("Port the parser")

        try await app.finishTurn(of: "Port the parser")
        #expect(try app.rowStatus(of: "Port the parser") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Port the parser"])
        #expect(app.notifications.map(\.title) == ["Port the parser"])

        try await app.clickRow(of: "Port the parser")
        #expect(try app.rowStatus(of: "Port the parser") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }
}
