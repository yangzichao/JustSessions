import Foundation

/// Names of the tmux sessions remote tabs run in. A session's own tab uses a name derived from its session id,
/// so resuming it again reattaches instead of starting a second CLI on the same session.
enum RemoteTmuxSessionName {
    static let prefix = "justsessions-"

    static func forConversation(_ conversation: Conversation) -> String {
        "\(prefix)\(RemoteCLICommandBuilder.executableName(for: conversation.provider))-\(conversation.sessionID)"
    }

    /// A new session or a branch has no session id of its own yet.
    static func unique(for provider: ConversationProvider) -> String {
        let suffix = UUID().uuidString.prefix(8).lowercased()
        return "\(prefix)\(RemoteCLICommandBuilder.executableName(for: provider))-new-\(suffix)"
    }
}
