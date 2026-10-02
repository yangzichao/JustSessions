import Foundation
@testable import JustSessions

struct TranscriptPagingFixture {
    let directory: URL
    let file: URL
    let sessionID = UUID().uuidString

    init(count: Int = 500, lineCount: Int = 1) throws {
        directory = try makeTemporaryDirectory()
        file = directory.appendingPathComponent("session.jsonl")
        try Self.data(count: count, lineCount: lineCount).write(to: file)
    }

    var conversation: Conversation { .fixture(provider: .codex, sessionID: sessionID, sourceFile: file) }
    func remove() { try? FileManager.default.removeItem(at: directory) }

    static func data(count: Int, lineCount: Int = 1) -> Data {
        Data((0..<count).map { index in
            let text = (0..<lineCount).map { "Message \(index), line \($0): keep this reading position." }.joined(separator: "\\n")
            return #"{"timestamp":"2026-10-02T12:00:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"\#(text)"}]}}"#
        }.joined(separator: "\n").appending("\n").utf8)
    }
}
