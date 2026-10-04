import CucumberSwift
import XCTest
@testable import JustSessions

/// The Claude Code steps of `Features/ClaudeLiveSession/RenameInClaudeCodeTab.feature`; the rest are `SessionTabSteps`.
@MainActor
enum ClaudeLiveRenameSteps {
    static func register() {
        registerGivenSteps()
        registerWhenSteps()
    }

    private static func registerGivenSteps() {
        Given("a tab resumed the Claude Code session {string}") { match, _ in
            let label = try match.first(\.string)
            try await world().app.listSession(labeled: label)
            try world().openResumedTab(on: label)
        }
        Given("a tab started a new Claude Code session") { _, _ in
            try world().openNewSessionTab()
        }
        Given("the sidebar lists the new session as {string}") { match, _ in
            try await world().listNewSession(as: try match.first(\.string))
        }
        Given("the sidebar lists the Claude Code session {string}") { match, _ in
            try await world().app.listSession(labeled: try match.first(\.string))
        }
        Given("Claude Code wrote the session {string}, which the sidebar does not list yet") { match, _ in
            try world().app.addSessionWithoutListing(labeled: try match.first(\.string))
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

    private static func world() throws -> ClaudeCodeTabWorld {
        try CurrentSessionTabWorld.world(madeBy: ClaudeCodeTabWorld.init)
    }
}
