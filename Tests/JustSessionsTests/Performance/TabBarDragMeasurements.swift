import AppKit
import Foundation
import Testing

@testable import JustSessions

@MainActor
@Suite(.serialized)
struct TabBarDragMeasurements {
    private static let groupKeys = ["/tmp/app", "/tmp/tools", "/tmp/site"]
    private static let tabsPerGroup = 6
    private static let stepCount = 120
    private static let stepDistance: CGFloat = 3

    @Test func movingATabAmongItsGroupsTabs() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        try await measure("tab among its group's tabs") { fixture, tabsByGroup in
            try fixture.middleAsLaidOut(ofTab: tabsByGroup[1][1].id)
        }
    }

    @Test func movingAGroupAmongTheGroups() async throws {
        guard ProcessInfo.processInfo.environment["JUSTSESSIONS_PERF"] != nil else { return }
        try await measure("group among the groups") { fixture, _ in
            try fixture.middle(ofGroupLabel: Self.groupKeys[0])
        }
    }

    private func measure(
        _ scenario: String,
        startingAt startX: (TabBarWindowFixture, [[TerminalSession]]) throws -> CGFloat
    ) async throws {
        var allDurations: [Duration] = []
        for _ in 0..<3 {
            let fixture = try TabBarWindowFixture()
            defer { fixture.close() }
            let tabsByGroup = Self.groupKeys.map { groupKey in
                (0..<Self.tabsPerGroup).map { fixture.openTab("Tab \($0)", in: groupKey) }
            }
            try await fixture.showTabBar()
            allDurations += try await fixture.timedDrag(
                fromX: startX(fixture, tabsByGroup), stepCount: Self.stepCount, by: Self.stepDistance
            )
            let tabIDsInOrder = fixture.store.terminalSessions.map(\.id)
            #expect(tabIDsInOrder != tabsByGroup.joined().map(\.id), "The drag moved nothing, so it measured nothing.")
        }
        let sorted = allDurations.sorted()
        perfReport("TabBarDragPerf", "\(scenario): moves", sorted.count)
        perfReport("TabBarDragPerf", "\(scenario): median move", Self.milliseconds(sorted[sorted.count / 2]))
        perfReport("TabBarDragPerf", "\(scenario): p90 move", Self.milliseconds(sorted[sorted.count * 9 / 10]))
        perfReport("TabBarDragPerf", "\(scenario): longest move", Self.milliseconds(sorted[sorted.count - 1]))
    }

    private static func milliseconds(_ duration: Duration) -> String {
        let milliseconds = Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
        return String(format: "%.2f ms", milliseconds)
    }
}
