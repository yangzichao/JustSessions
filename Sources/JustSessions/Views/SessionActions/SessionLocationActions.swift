import AppKit

enum SessionLocationActions {
    static func copySessionID(_ conversation: Conversation) {
        copyToPasteboard(conversation.sessionID)
    }

    static func copyProjectPath(_ projectPath: String) {
        copyToPasteboard(projectPath)
    }

    static func revealSessionFile(_ conversation: Conversation) {
        NSWorkspace.shared.activateFileViewerSelecting([conversation.sourceFile])
    }

    static func openProjectFolder(_ projectPath: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: projectPath))
    }

    private static func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
