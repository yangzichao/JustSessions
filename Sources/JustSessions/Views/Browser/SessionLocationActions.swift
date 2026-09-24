import AppKit

enum SessionLocationActions {
    static func copySessionID(_ conversation: Conversation) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(conversation.sessionID, forType: .string)
    }

    static func copyProjectPath(_ projectPath: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(projectPath, forType: .string)
    }

    static func revealSessionFile(_ conversation: Conversation) {
        NSWorkspace.shared.activateFileViewerSelecting([conversation.sourceFile])
    }

    static func openProjectFolder(_ projectPath: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: projectPath))
    }
}
