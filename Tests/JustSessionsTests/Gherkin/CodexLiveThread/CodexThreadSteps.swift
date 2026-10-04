import CucumberSwift
import XCTest
@testable import JustSessions

/// The Codex steps of `Features/CodexLiveThread/FollowCodexThread.feature`; the rest are `SessionTabSteps`.
@MainActor
enum CodexThreadSteps {
    static func register() {
        registerGivenSteps()
        registerWhenSteps()
    }

    private static func registerGivenSteps() {
        Given("a tab resumed the Codex session {string}") { match, _ in
            let label = try match.first(\.string)
            try await world().app.listSession(labeled: label)
            try world().openResumedTab(on: label)
        }
        Given("a tab started a new Codex session") { _, _ in
            try world().openNewSessionTab()
        }
        Given("the sidebar lists the Codex session {string}") { match, _ in
            try await world().app.listSession(labeled: try match.first(\.string))
        }
        Given("Codex saved the session {string}, which the sidebar does not list yet") { match, _ in
            try world().saveThread(labeled: try match.first(\.string))
        }
    }

    private static func registerWhenSteps() {
        When("the Codex CLI in the tab moves to {string} with \\/new") { match, _ in
            try await world().cliMoves(toThreadLabeled: try match.first(\.string))
        }
        When("the Codex CLI in the tab moves with \\/new to {string}, which Codex has not saved yet") { match, _ in
            try await moveToUnsavedThread(labeled: try match.first(\.string))
        }
        When("the Codex CLI in the tab starts {string}, which Codex has not saved yet") { match, _ in
            try await moveToUnsavedThread(labeled: try match.first(\.string))
        }
        When("Codex saves {string} with its first prompt") { match, _ in
            let world = try world()
            try world.saveThread(labeled: try match.first(\.string))
            await world.followTheCLIOnce()
        }
        When("the Codex CLI in the tab sets the title {string}") { match, _ in
            try await world().cliSetsTitle(try match.first(\.string))
        }
    }

    private static func moveToUnsavedThread(labeled label: String) async throws {
        let world = try world()
        world.app.reserveSessionID(labeled: label)
        try await world.cliMoves(toThreadLabeled: label)
    }

    private static func world() throws -> CodexTabWorld {
        try CurrentSessionTabWorld.world(madeBy: CodexTabWorld.init)
    }
}
