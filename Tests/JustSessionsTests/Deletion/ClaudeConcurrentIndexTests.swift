import Foundation
import Testing
@testable import JustSessions

struct ClaudeConcurrentIndexTests {
    @Test func concurrentRemovalsPreserveEveryIndexUpdate() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let index = directory.appendingPathComponent("sessions-index.json")
        let entries = (0..<5_000).map { ["sessionId": "session-\($0)"] }
        try JSONSerialization.data(withJSONObject: ["entries": entries]).write(to: index)
        let failures = IndexWriteFailures()
        DispatchQueue.concurrentPerform(iterations: 8) { number in
            do { try ClaudeConversationIndex.remove(sessionIDs: ["session-\(number)"], in: directory) }
            catch { failures.record(error) }
        }
        #expect(failures.messages.isEmpty)
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: index)) as? [String: Any])
        let remaining = try #require(object["entries"] as? [[String: String]])
        #expect(remaining.count == 4_992)
        #expect(Set(remaining.compactMap { $0["sessionId"] }).isDisjoint(with: (0..<8).map { "session-\($0)" }))
    }
}

private final class IndexWriteFailures: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []
    var messages: [String] { lock.withLock { values } }
    func record(_ error: any Error) { lock.withLock { values.append(error.localizedDescription) } }
}
