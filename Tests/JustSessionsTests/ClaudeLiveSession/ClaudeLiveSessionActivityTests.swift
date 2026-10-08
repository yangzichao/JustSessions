import Foundation
import Testing
@testable import JustSessions

struct ClaudeLiveSessionActivityTests {
    private static let sessionID = "70b71200-8814-4822-a2e5-24abf31f7cbd"

    private static func activity(status: String?, waitingFor: String? = nil) throws -> CLIActivity? {
        var object: [String: Any] = ["sessionId": sessionID]
        object["status"] = status
        object["waitingFor"] = waitingFor
        let record = try #require(ClaudeLiveSessionRecord(jsonData: try JSONSerialization.data(withJSONObject: object)))
        return record.activity
    }

    @Test func readsWhatTheCLIIsDoingFromItsStatus() throws {
        #expect(try Self.activity(status: "busy") == .working)
        #expect(try Self.activity(status: "idle") == .idle)
        // Between turns, while a shell command Claude Code started in the background still runs.
        #expect(try Self.activity(status: "shell") == .idle)
        #expect(try Self.activity(status: "waiting", waitingFor: "input needed") == .needsInput(reason: "input needed"))
    }

    @Test func aWaitWithoutAReasonStillNeedsInput() throws {
        #expect(try Self.activity(status: "waiting") == .needsInput(reason: nil))
        #expect(try Self.activity(status: "waiting", waitingFor: " \n") == .needsInput(reason: nil))
    }

    @Test func shortensALongWaitReason() throws {
        let activity = try Self.activity(status: "waiting", waitingFor: String(repeating: "x", count: 500))
        #expect(activity == .needsInput(reason: String(repeating: "x", count: CLIActivity.maximumWaitReasonLength)))
    }

    @Test func anUnknownOrMissingStatusTellsNothing() throws {
        #expect(try Self.activity(status: "compacting") == nil)
        #expect(try Self.activity(status: nil) == nil)
    }
}
