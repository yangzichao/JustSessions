import CucumberSwift
import XCTest
@testable import JustSessions

/// The steps of `Features/LiveSessionFollowing/FollowLiveSession.feature`; the rest are `SessionTabSteps`.
@MainActor
enum LiveSessionSteps {
    static func register() {
        registerGivenSteps()
        registerWhenSteps()
    }

    private static func registerGivenSteps() {
        Given("a tab whose {word} CLI resumed the session {string}") { match, _ in
            let world = try CurrentSessionTabWorld.world { try LiveSessionTabWorld(toolName: try match.first(\.word)) }
            let label = try match.first(\.string)
            try await world.app.listSession(labeled: label)
            try world.openResumedTab(on: label)
        }
        Given("a tab whose {word} CLI started a new session") { match, _ in
            try CurrentSessionTabWorld.world { try LiveSessionTabWorld(toolName: try match.first(\.word)) }.openNewSessionTab()
        }
        Given("the sidebar lists the session {string}") { match, _ in
            try await world().app.listSession(labeled: try match.first(\.string))
        }
    }

    private static func registerWhenSteps() {
        When("the CLI in the tab moves to {string}") { match, _ in
            try await world().cliMoves(toSessionLabeled: try match.first(\.string))
        }
        When("the CLI in the tab moves to {string}, which it has not saved yet") { match, _ in
            let world = try world()
            let label = try match.first(\.string)
            world.app.reserveSessionID(labeled: label)
            try await world.cliMoves(toSessionLabeled: label)
        }
        When("the CLI saves {string}") { match, _ in
            let world = try world()
            try world.saveSession(labeled: try match.first(\.string))
            await world.followTheCLIOnce()
        }
        When("the OpenCode CLI in the tab shows its home screen") { _, _ in
            let world = try world()
            try XCTUnwrap(world.cli as? ScenarioOpenCodeCLI, "The tab does not run OpenCode").showsItsHomeScreen()
            await world.followTheCLIOnce()
        }
    }

    private static func world() throws -> LiveSessionTabWorld {
        try XCTUnwrap(try CurrentSessionTabWorld.require() as? LiveSessionTabWorld, "The scenario's tab runs a CLI of another tool")
    }
}
