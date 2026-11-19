import Foundation

struct AntigravityCLILogTail: Sendable {
    static let chunkByteCount = 1 << 20

    private(set) var conversationID: String?
    private var readByteCount: UInt64 = 0

    mutating func readNewLines(of file: URL) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return }
        defer { try? handle.close() }
        guard let fileSize = try? handle.seekToEnd() else { return }
        if fileSize < readByteCount { self = AntigravityCLILogTail() }
        while readByteCount < fileSize {
            guard (try? handle.seek(toOffset: readByteCount)) != nil,
                let chunk = try? handle.read(upToCount: Self.chunkByteCount), !chunk.isEmpty
            else { return }
            guard let lastNewline = chunk.lastIndex(of: UInt8(ascii: "\n")) else {
                if chunk.count < Self.chunkByteCount { return }
                readByteCount += UInt64(chunk.count)
                continue
            }
            let completeLines = chunk[chunk.startIndex...lastNewline]
            readByteCount += UInt64(completeLines.count)
            if let conversationID = AntigravityCLILog.lastConversationID(in: String(decoding: completeLines, as: UTF8.self)) {
                self.conversationID = conversationID
            }
        }
    }
}
