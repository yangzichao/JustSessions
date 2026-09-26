import Foundation
@testable import JustSessions

extension Conversation {
    /// A conversation with plain defaults, so a test spells out only what it checks.
    static func fixture(
        provider: ConversationProvider = .claude,
        sessionID: String = UUID().uuidString.lowercased(),
        projectPath: String = "/tmp/justsessions-tests/project",
        title: String = "Session",
        updatedAt: Date = .now,
        sourceFile: URL? = nil,
        host: SessionHost = .thisMac
    ) -> Conversation {
        Conversation(
            provider: provider,
            sessionID: sessionID,
            projectPath: projectPath,
            suggestedTitle: title,
            updatedAt: updatedAt,
            sourceFile: sourceFile ?? URL(fileURLWithPath: "/tmp/justsessions-tests/\(sessionID).jsonl"),
            host: host
        )
    }
}
