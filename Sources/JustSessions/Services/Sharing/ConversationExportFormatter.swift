import Foundation

enum ConversationExportFormatter {
    static func text(for sessions: [ConversationExportDocument.SessionTranscript], in format: ConversationExportFormat) throws -> String {
        var sections: [String] = []
        for session in sessions {
            try Task.checkCancellation()
            let conversation = session.selection.conversation
            let title = singleLine(session.selection.title)
            var blocks = [format == .markdown ? "# \(title)" : title]
            let metadata = [
                "Provider: \(conversation.provider.rawValue)",
                "Session ID: \(singleLine(conversation.sessionID))",
                "Project: \(singleLine(conversation.projectLocation.copyablePath))",
                "Host: \(singleLine(conversation.host.displayName))",
                "Updated: \(conversation.updatedAt.ISO8601Format())",
            ]
            blocks.append(metadata.map { format == .markdown ? "- \($0)" : $0 }.joined(separator: "\n"))
            for entry in session.transcript.entries {
                try Task.checkCancellation()
                let heading: String
                let body: String
                switch entry.content {
                case .userMessage(let text):
                    heading = "You"
                    body = text
                case .assistantMessage(let text):
                    heading = conversation.provider.rawValue
                    body = text
                case .toolCalls(let summaries):
                    heading = "Tool calls (summaries)"
                    let text = summaries.joined(separator: "\n")
                    body = format == .markdown ? fenced(text) : text
                case .note(let text):
                    heading = "Note"
                    body = text
                }
                let timestamp = entry.timestamp.map { " · \($0.ISO8601Format())" } ?? ""
                blocks.append((format == .markdown ? "## " : "") + heading + timestamp + "\n\n" + body)
            }
            sections.append(blocks.joined(separator: "\n\n"))
        }
        return sections.joined(separator: "\n\n---\n\n") + "\n"
    }

    private static func singleLine(_ text: String) -> String {
        text.components(separatedBy: .newlines).joined(separator: " ")
    }

    private static func fenced(_ text: String) -> String {
        var longestRun = 0
        var currentRun = 0
        for character in text {
            currentRun = character == "`" ? currentRun + 1 : 0
            longestRun = max(longestRun, currentRun)
        }
        let fence = String(repeating: "`", count: max(3, longestRun + 1))
        return "\(fence)\n\(text)\n\(fence)"
    }
}
