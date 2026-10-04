import CucumberSwift
import XCTest
@testable import JustSessions

/// The steps of `Features/ClaudeLiveSession/RenameInClaudeCodeTab.feature`.
@MainActor
enum ClaudeLiveRenameSteps {
    private static var currentWorld: ClaudeCodeTabWorld?

    static func register() {
        AfterScenario { _ in
            currentWorld?.tearDown()
            currentWorld = nil
        }

        registerGivenSteps()
        registerWhenSteps()
        registerThenSteps()
    }

    private static func registerGivenSteps() {
        Given("a tab resumed the Claude Code session {string}") { match, _ in
            let label = try match.first(\.string)
            try await world().listSession(labeled: label)
            try world().openResumedTab(on: label)
        }
        Given("a tab started a new Claude Code session") { _, _ in
            try world().openNewSessionTab()
        }
        Given("the sidebar lists the new session as {string}") { match, _ in
            try await world().listNewSession(as: try match.first(\.string))
        }
        Given("the sidebar lists the Claude Code session {string}") { match, _ in
            try await world().listSession(labeled: try match.first(\.string))
        }
        Given("Claude Code wrote the session {string}, which the sidebar does not list yet") { match, _ in
            try world().writeSessionWithoutListing(labeled: try match.first(\.string))
        }
    }

    private static func registerWhenSteps() {
        When("the CLI in the tab is renamed to {string}") { match, _ in
            try world().cliChoosesName(try match.first(\.string), source: "user")
        }
        When("the CLI in the tab names itself {string}") { match, _ in
            try world().cliChoosesName(try match.first(\.string), source: "derived")
        }
        When("the CLI in the tab moves to {string} with \\/clear") { match, _ in
            try world().cliMoves(toSessionLabeled: try match.first(\.string))
        }
    }

    private static func registerThenSteps() {
        Then("the tab is titled {string}") { match, _ in
            XCTAssertEqual(try world().tab?.displayTitle, try match.first(\.string))
        }
        Then("the tab shows the session {string}") { match, _ in
            let world = try world()
            let sessionID = try world.sessionID(labeled: try match.first(\.string))
            let followed = try await world.keepSynchronizing { world.tab?.conversation?.sessionID == sessionID }
            XCTAssertTrue(followed, "The tab still shows session \(world.tab?.conversation?.sessionID ?? "none")")
        }
        Then("the sidebar (still )lists {string}") { match, _ in
            let world = try world()
            let title = try match.first(\.string)
            let isListed = try await world.eventually { world.sidebarLists(title) }
            XCTAssertTrue(isListed, "The sidebar does not list \"\(title)\"")
        }
        Then("the sidebar no longer lists {string}") { match, _ in
            let title = try match.first(\.string)
            XCTAssertFalse(try world().sidebarLists(title), "The sidebar still lists \"\(title)\"")
        }
    }

    private static func world() throws -> ClaudeCodeTabWorld {
        if let currentWorld { return currentWorld }
        let createdWorld = try ClaudeCodeTabWorld()
        currentWorld = createdWorld
        return createdWorld
    }
}
