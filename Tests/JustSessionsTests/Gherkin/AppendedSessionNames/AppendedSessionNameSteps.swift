import CucumberSwift
import XCTest
@testable import JustSessions

/// The steps of `Features/AppendedSessionNames/RenameFromSessionFiles.feature`; the rest are `SessionTabSteps`.
@MainActor
enum AppendedSessionNameSteps {
    static func register() {
        Given("a {word} tab is open on the session {string}") { match, _ in
            let world = try CurrentSessionTabWorld.world { try AppendedSessionNameWorld(toolName: try match.first(\.word)) }
            try await world.openTab(on: try match.first(\.string))
        }
        Given("the session is renamed {string} in the app") { match, _ in
            try world().renameInApp(try match.first(\.string))
        }
        When("the CLI appends the name {string}") { match, _ in
            try await world().cliAppendsName(try match.first(\.string))
        }
        When("Codex appends the name {string} for another thread") { match, _ in
            try await world().cliAppendsName(try match.first(\.string), forSessionID: UUID().uuidString.lowercased())
        }
    }

    private static func world() throws -> AppendedSessionNameWorld {
        try XCTUnwrap(try CurrentSessionTabWorld.require() as? AppendedSessionNameWorld, "The scenario's tab runs a CLI of another tool")
    }
}
