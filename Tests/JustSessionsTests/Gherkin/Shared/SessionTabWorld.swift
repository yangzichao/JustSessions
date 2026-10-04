import Foundation
import XCTest
@testable import JustSessions

/// One scenario's app and the one tab whose CLI the scenario drives. Each tool's steps keep their own world; the steps
/// every tab feature shares reach it through `CurrentSessionTabWorld`.
@MainActor
protocol SessionTabWorld: AnyObject {
    var app: ScenarioApp { get }
    var tab: TerminalSession? { get }
    /// What the app does every second to keep the tab with the session its CLI is in.
    func followTheCLIOnce() async
}

extension SessionTabWorld {
    /// Follows the CLI as the app does every second, until `condition` holds or time runs out.
    func keepFollowingTheCLI(until condition: () -> Bool) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + ScenarioApp.timeout
        while true {
            await followTheCLIOnce()
            if condition() { return true }
            guard clock.now < deadline else { return false }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}

/// The world of the scenario that runs, made by the first step that needs it and torn down after the scenario.
@MainActor
enum CurrentSessionTabWorld {
    private static var world: (any SessionTabWorld)?

    static func world<World: SessionTabWorld>(madeBy makeWorld: () throws -> World) throws -> World {
        if let world {
            return try XCTUnwrap(world as? World, "The scenario's tab runs a CLI of another tool")
        }
        let madeWorld = try makeWorld()
        world = madeWorld
        return madeWorld
    }

    static func require() throws -> any SessionTabWorld {
        try XCTUnwrap(world, "No step opened a tab")
    }

    static func tearDown() {
        world?.app.tearDown()
        world = nil
    }
}
