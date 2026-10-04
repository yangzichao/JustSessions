import Foundation
import Testing
@testable import JustSessions

struct CodexRolloutLocatorTests {
    private static let threadID = "01a10846-4c77-75e2-bec8-ab638c1d2e3f"
    private static let threadIDPrefix = "01a10846-4c77-75e2-bec8-ab638"

    @Test func findsTheThreadFromTheStartOfItsID() throws {
        let codexHome = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: codexHome) }
        try writeRollout(of: "01a10846-4c77-75e2-bec8-000000000000", day: "2026/10/04", in: codexHome)
        try writeRollout(of: Self.threadID, day: "2026/10/04", in: codexHome)

        let locator = CodexRolloutLocator(codexDirectory: codexHome)

        #expect(locator.sessionID(forThreadIDPrefix: Self.threadIDPrefix, startedOnOrAfter: nil) == Self.threadID)
        #expect(locator.sessionID(forThreadIDPrefix: "01a10846-4c77-75e2-bec8-ffffff", startedOnOrAfter: nil) == nil)
    }

    @Test func waitsUntilTheRolloutOpensWithItsSessionMeta() throws {
        let codexHome = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: codexHome) }
        let rollout = try writeRollout(of: Self.threadID, day: "2026/10/04", in: codexHome, firstLine: "")
        let locator = CodexRolloutLocator(codexDirectory: codexHome)

        #expect(locator.sessionID(forThreadIDPrefix: Self.threadIDPrefix, startedOnOrAfter: nil) == nil)

        try (Self.sessionMeta(of: Self.threadID) + "\n").write(to: rollout, atomically: true, encoding: .utf8)
        #expect(locator.sessionID(forThreadIDPrefix: Self.threadIDPrefix, startedOnOrAfter: nil) == Self.threadID)
    }

    @Test func looksBackOnlyToTheDayBeforeTheLastRefresh() throws {
        let codexHome = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: codexHome) }
        try writeRollout(of: Self.threadID, day: "2026/10/02", in: codexHome)
        var locator = CodexRolloutLocator(codexDirectory: codexHome)
        locator.calendar = Calendar(identifier: .gregorian)
        locator.calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let lastRefresh = try #require(ISO8601DateFormatter().date(from: "2026-10-04T12:00:00Z"))
        let refreshTheDayAfter = try #require(ISO8601DateFormatter().date(from: "2026-10-03T12:00:00Z"))

        #expect(locator.sessionID(forThreadIDPrefix: Self.threadIDPrefix, startedOnOrAfter: lastRefresh) == nil)
        #expect(locator.sessionID(forThreadIDPrefix: Self.threadIDPrefix, startedOnOrAfter: refreshTheDayAfter) == Self.threadID)
    }

    private static func sessionMeta(of threadID: String) -> String {
        #"{"type":"session_meta","payload":{"id":"\#(threadID)","cwd":"/Users/me/app"}}"#
    }

    @discardableResult
    private func writeRollout(of threadID: String, day: String, in codexHome: URL, firstLine: String? = nil) throws -> URL {
        let dayDirectory = codexHome.appendingPathComponent("sessions/\(day)")
        try FileManager.default.createDirectory(at: dayDirectory, withIntermediateDirectories: true)
        let rollout = dayDirectory.appendingPathComponent(
            "rollout-\(day.replacingOccurrences(of: "/", with: "-"))T10-00-00-\(threadID).jsonl"
        )
        try ((firstLine ?? Self.sessionMeta(of: threadID)) + "\n").write(to: rollout, atomically: true, encoding: .utf8)
        return rollout
    }
}
