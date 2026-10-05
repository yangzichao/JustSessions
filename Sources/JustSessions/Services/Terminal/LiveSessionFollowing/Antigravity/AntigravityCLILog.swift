import Foundation

/// The log an Antigravity CLI writes while it runs, `log/cli-<start time>.log` in Antigravity's folder. The CLI holds
/// it open, and logs `Starting conversation update stream for <id>` each time it opens a conversation: with the first
/// prompt of a new one, and with `/clear`, `/resume`, and `/fork`. The last such line names the conversation it is in.
enum AntigravityCLILog {
    static let conversationStreamMarker = "Starting conversation update stream for "

    /// The conversation the last line in `text` that opens a conversation stream names.
    static func lastConversationID(in text: String) -> String? {
        var searchEnd = text.endIndex
        while let markerRange = text.range(of: conversationStreamMarker, options: .backwards, range: text.startIndex..<searchEnd) {
            let candidate = String(text[markerRange.upperBound...].prefix(36))
            if ConversationProvider.antigravity.isValidSessionID(candidate) { return candidate }
            searchEnd = markerRange.lowerBound
        }
        return nil
    }

    static func isCLILog(atPath path: String, configurationDirectory: URL) -> Bool {
        let file = URL(fileURLWithPath: path).resolvingSymlinksInPath()
        let logDirectory = configurationDirectory.appendingPathComponent("log").resolvingSymlinksInPath()
        return file.deletingLastPathComponent().path == logDirectory.path
            && file.lastPathComponent.hasPrefix("cli-") && file.pathExtension == "log"
    }
}
