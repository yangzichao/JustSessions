import Foundation

enum TranscriptTestFiles {
    /// Writes one JSON object per line to a temporary `.jsonl` file.
    static func write(_ records: [[String: Any]]) throws -> URL {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).jsonl")
        let lines = try records.map { record in
            String(decoding: try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]), as: UTF8.self)
        }
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return file
    }
}
