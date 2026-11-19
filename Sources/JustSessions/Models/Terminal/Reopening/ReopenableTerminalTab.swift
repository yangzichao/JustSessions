import Foundation

struct ReopenableTerminalTab: Codable, Equatable, Sendable {
    let conversationID: String?
    let projectDirectoryKey: String
    let wasSelected: Bool
    var tmuxSessionName: String? = nil

    var isPlainTerminal: Bool { conversationID == nil }
    var host: SessionHost { ProjectLocation(key: projectDirectoryKey).host }
}

extension ReopenableTerminalTab {
    @MainActor
    init?(tab: TerminalSession, selectedTerminalID: UUID?) {
        if !tab.isPlainTerminal && tab.conversation == nil { return nil }
        self.init(
            conversationID: tab.conversation?.id,
            projectDirectoryKey: tab.projectDirectoryKey,
            wasSelected: tab.id == selectedTerminalID,
            tmuxSessionName: tab.isPlainTerminal ? tab.tmuxSessionName : nil
        )
    }
}
