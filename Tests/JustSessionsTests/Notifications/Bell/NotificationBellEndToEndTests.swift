import Foundation
import Testing

@testable import JustSessions

@MainActor
struct NotificationBellEndToEndTests {
    @Test func aTurnThatFinishesOffScreenIsListedUntilYouLook() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")
        #expect(app.notificationBellTitles.isEmpty)

        try await app.finishTurn(of: "Revise the abstract")
        #expect(app.notificationBellTitles == ["Revise the abstract"])
        #expect(app.notificationBellReasons == [.finishedTurn])
        #expect(try app.notificationBellEntry(of: "Revise the abstract").waitingSince != nil)

        try await app.clickNotificationBellRow(of: "Revise the abstract")
        #expect(app.notificationBellTitles.isEmpty)
        try app.select("Check the references")
        #expect(app.notificationBellTitles.isEmpty)
    }

    @Test func aCLIStoppedForYourAnswerIsListedWhileItsTerminalIsOffScreenUntilYouAnswer() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")

        try await app.stopForAnswer(in: "Revise the abstract")
        #expect(app.notificationBellTitles == ["Revise the abstract"])
        #expect(app.notificationBellReasons == [.needsInput(reason: "permission prompt")])
        let waitingSince = try app.notificationBellEntry(of: "Revise the abstract").waitingSince

        try app.select("Revise the abstract")
        #expect(app.notificationBellTitles.isEmpty)
        try app.select("Check the references")
        await app.followCLIsOnce()
        #expect(try app.notificationBellEntry(of: "Revise the abstract").waitingSince == waitingSince)

        try app.select("Revise the abstract")
        try await app.sendPrompt("Yes", in: "Revise the abstract")
        try app.select("Check the references")
        #expect(app.notificationBellTitles.isEmpty)
    }

    @Test func theWaitThatStartedLastIsListedFirst() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Port the parser", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Port the parser")
        try await app.sendPrompt("Port it to Swift", in: "Port the parser")
        try await app.resume("Check the references")

        try await app.finishTurn(of: "Revise the abstract")
        try await app.stopForAnswer(in: "Port the parser")
        #expect(app.notificationBellTitles == ["Port the parser", "Revise the abstract"])
        #expect(app.notificationBellReasons == [.needsInput(reason: "permission prompt"), .finishedTurn])
    }

    @Test func aSessionWhoseTabClosedWithItsCLIRunningInTmuxStaysListedAndClickingItReattaches() async throws {
        guard let app = try UnseenTurnSandboxApp.make() else { return }
        defer { app.tearDown() }
        try await app.saveSession("Revise the abstract", of: .claude)
        try await app.saveSession("Check the references", of: .claude)
        try await app.resume("Revise the abstract")
        try await app.sendPrompt("Tighten the abstract", in: "Revise the abstract")
        try await app.resume("Check the references")
        try await app.finishTurn(of: "Revise the abstract")
        let waitingSince = try app.notificationBellEntry(of: "Revise the abstract").waitingSince

        try app.closeTabKeepingItsCLIRunning("Revise the abstract")
        await app.followCLIsOnce()
        let entry = try app.notificationBellEntry(of: "Revise the abstract")
        #expect(entry.source == .detachedTmux(conversationID: try app.conversation("Revise the abstract").id))
        #expect(entry.waitingSince == waitingSince)

        try await app.clickNotificationBellRow(of: "Revise the abstract")
        #expect(app.store.selectedTerminalID == (try app.tab(of: "Revise the abstract").id))
        #expect(app.notificationBellTitles.isEmpty)
    }
}
