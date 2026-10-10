/// Finds Ghostty's answer to a background color query (`OSC 11 ; ?`) in what it sends the tab's process:
/// `OSC 11 ; rgb:…` ended by BEL or `ESC \`, as Ghostty writes it (`termio/stream_handler.zig`). Ghostty writes each
/// answer whole, in one write, so only an answer within one write is found.
enum GhosttyBackgroundColorAnswer {
    private static let start = Array("\u{1B}]11;".utf8)
    private static let bell: UInt8 = 0x07
    private static let escape: UInt8 = 0x1B

    /// The index just after the first answer's terminator, or nil without a whole answer.
    static func endIndex(in bytes: [UInt8]) -> Int? {
        var index = bytes.startIndex
        while index < bytes.endIndex {
            guard bytes[index...].starts(with: start) else {
                index += 1
                continue
            }
            var end = index + start.count
            while end < bytes.endIndex {
                if bytes[end] == bell { return end + 1 }
                if bytes[end] == escape {
                    if end + 1 < bytes.endIndex, bytes[end + 1] == UInt8(ascii: "\\") { return end + 2 }
                    break
                }
                end += 1
            }
            index = end
        }
        return nil
    }
}
