import Foundation

/// A tab open when the app quit, as much of it as reopens it at the next launch: the session it ran, or for a plain
/// terminal its folder.
struct ReopenableTerminalTab: Codable, Equatable, Sendable {
    /// The session the tab ran, by `Conversation.id`; nil for a plain terminal.
    let conversationID: String?
    /// The tab's project, by `ProjectLocation.key`, which also names its host.
    let projectDirectoryKey: String
    let wasSelected: Bool

    var isPlainTerminal: Bool { conversationID == nil }
    var host: SessionHost { ProjectLocation(key: projectDirectoryKey).host }
}

extension ReopenableTerminalTab {
    /// Nil for a New session or Branch tab whose session is not known yet: there is nothing to resume.
    @MainActor
    init?(tab: TerminalSession, selectedTerminalID: UUID?) {
        if !tab.isPlainTerminal && tab.conversation == nil { return nil }
        self.init(
            conversationID: tab.conversation?.id,
            projectDirectoryKey: tab.projectDirectoryKey,
            wasSelected: tab.id == selectedTerminalID
        )
    }
}
