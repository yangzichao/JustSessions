import CucumberSwift
import XCTest
@testable import JustSessions

/// The steps every tab feature shares: what the tab and the sidebar show, whichever CLI the tab runs.
@MainActor
enum SessionTabSteps {
    static func register() {
        AfterScenario { _ in
            CurrentSessionTabWorld.tearDown()
        }

        Then("the tab is titled {string}") { match, _ in
            XCTAssertEqual(try CurrentSessionTabWorld.require().tab?.displayTitle, try match.first(\.string))
        }
        Then("the tab shows the session {string}") { match, _ in
            let world = try CurrentSessionTabWorld.require()
            let sessionID = try world.app.sessionID(labeled: try match.first(\.string))
            let followed = try await world.keepFollowingTheCLI { world.tab?.conversation?.sessionID == sessionID }
            XCTAssertTrue(followed, "The tab shows session \(world.tab?.conversation?.sessionID ?? "none")")
        }
        Then("the sidebar (still )lists {string}") { match, _ in
            let app = try CurrentSessionTabWorld.require().app
            let title = try match.first(\.string)
            let isListed = try await app.eventually { app.sidebarLists(title) }
            XCTAssertTrue(isListed, "The sidebar does not list \"\(title)\"")
        }
        Then("the sidebar no longer lists {string}") { match, _ in
            let title = try match.first(\.string)
            XCTAssertFalse(try CurrentSessionTabWorld.require().app.sidebarLists(title), "The sidebar still lists \"\(title)\"")
        }
    }
}
