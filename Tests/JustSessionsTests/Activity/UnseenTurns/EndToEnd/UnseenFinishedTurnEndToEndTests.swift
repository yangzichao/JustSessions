import Foundation
import Testing
@testable import JustSessions

/// A session whose CLI finished its turn while you were not looking keeps a dot until you look, and Waiting for you
/// lists it meanwhile. Each test runs the app's own launch, tmux, activity sync, and sidebar filtering against CLIs
/// that report what they do as Claude Code and Codex do; see `UnseenTurnSandboxApp`.
@MainActor
struct UnseenFinishedTurnEndToEndTests {
    @Test func aTurnThatFinishesInATabYouAreNotLookingAtKeepsADotUntilYouSelectTheTab() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.working))
        #expect(app.waitingForYou.titles.isEmpty)

        try await app.finishTurn(of: "Revise the abstract")
        #expect(try app.tab(of: "Revise the abstract").runStatus == .finishedUnseen)
        #expect(try app.rowStatus(of: "Revise the abstract") == .finishedUnseen)
        #expect(try app.projectStatus(of: "Revise the abstract") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Revise the abstract"])
        #expect(app.waitingForYou.count == 1)
        #expect(app.notifications.map(\.title) == ["Revise the abstract"])
        #expect(app.notifications.map(\.reason) == [.finishedTurn])

        // The dot outlasts the notification, for as long as you don't look.
        await app.followCLIsOnce()
        await app.followCLIsOnce()
        #expect(try app.rowStatus(of: "Revise the abstract") == .finishedUnseen)

        try app.select("Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.idle))
        #expect(try app.projectStatus(of: "Revise the abstract") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
        #expect(app.waitingForYou.count == 0)
        await app.followCLIsOnce()
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.idle))
    }

    @Test func aTurnThatFinishesInTheTabYouAreLookingAtLeavesNoDot() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.resume("Revise the abstract")

        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.finishTurn(of: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
        #expect(app.notifications.isEmpty)
    }

    @Test func aTurnThatFinishesWhileTheAppIsBehindKeepsTheDotUntilTheAppComesToTheFront() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")

        app.notifier.isApplicationActive = false
        try await app.finishTurn(of: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Revise the abstract"])
        #expect(app.notifications.map(\.reason) == [.finishedTurn])

        await app.bringAppToFront()
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func aCLIStoppedForYourAnswerWaitsForYouWithoutADotUntilYouAnswer() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")

        try await app.stopForAnswer(in: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.needsInput(reason: "permission prompt")))
        // A project sums up its CLIs, so it shows no one CLI's reason.
        #expect(try app.projectStatus(of: "Revise the abstract") == .running(.needsInput(reason: nil)))
        #expect(app.waitingForYou.titles == ["Revise the abstract"])
        #expect(app.notifications.map(\.reason) == [.needsInput(reason: "permission prompt")])

        try app.select("Revise the abstract")
        // Looking at it does not answer it.
        #expect(app.waitingForYou.titles == ["Revise the abstract"])
        try await app.sendPrompt("Yes", in: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.working))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func theDotStaysWithASessionWhoseTabClosedWithItsCLIRunningInTmuxUntilYouReattach() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")
        try await app.finishTurn(of: "Revise the abstract")

        try app.closeTabKeepingItsCLIRunning("Revise the abstract")
        await app.followCLIsOnce()
        #expect(app.store.isRunningInTmux(try app.conversation("Revise the abstract")))
        #expect(try app.rowStatus(of: "Revise the abstract") == .finishedUnseen)
        #expect(try app.projectStatus(of: "Revise the abstract") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Revise the abstract"])

        try await app.clickRow(of: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func aCodexTurnThatFinishesOffScreenKeepsADotUntilYouShowItInASplit() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Port the parser", of: .codex)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Port the parser")
        try await app.sendPrompt("Port it to Swift", in: "Port the parser")
        try await app.resume("Check the references")

        try await app.finishTurn(of: "Port the parser")
        #expect(try app.rowStatus(of: "Port the parser") == .finishedUnseen)
        #expect(app.waitingForYou.titles == ["Port the parser"])
        #expect(app.notifications.map(\.title) == ["Port the parser"])

        app.store.splitSelectedTerminal(with: try app.tab(of: "Port the parser").id)
        #expect(try app.rowStatus(of: "Port the parser") == .running(.idle))
        #expect(app.waitingForYou.titles.isEmpty)
    }

    @Test func aCLIThatQuitsTakesItsDotWithIt() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")
        try await app.finishTurn(of: "Revise the abstract")
        #expect(app.waitingForYou.titles == ["Revise the abstract"])

        try await app.quitCLI(in: "Revise the abstract")
        #expect(try app.rowStatus(of: "Revise the abstract") == .ended)
        #expect(app.waitingForYou.titles.isEmpty)
    }
}
