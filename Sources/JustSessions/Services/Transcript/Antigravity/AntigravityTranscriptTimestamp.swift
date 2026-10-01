import Foundation

enum AntigravityTranscriptTimestamp {
    static func date(in payload: Data) -> Date? {
        guard let timestamp = AntigravityProtobuf.bytes(in: payload, at: [5, 1]) else { return nil }
        let seconds = Int64(bitPattern: AntigravityProtobuf.integer(in: timestamp, field: 1) ?? 0)
        let nanoseconds = AntigravityProtobuf.integer(in: timestamp, field: 2) ?? 0
        guard nanoseconds < 1_000_000_000 else { return nil }
        return Date(timeIntervalSince1970: Double(seconds) + Double(nanoseconds) / 1_000_000_000)
    }
}
