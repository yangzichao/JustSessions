import Foundation

enum ConversationExportError: LocalizedError {
    case emptySelection
    case unsupported(ConversationExportSelection)
    case noMessages(ConversationExportSelection)
    case unreadable(ConversationExportSelection, reason: String)
    case clipboardUnavailable

    var errorDescription: String? {
        switch self {
        case .emptySelection: "Choose a conversation to copy or export."
        case .unsupported(let selection): "JustSessions can't read \(selection.conversation.provider.rawValue) conversations yet."
        case .noMessages(let selection): "“\(selection.title)” has no saved messages yet."
        case .unreadable(let selection, let reason): "Could not read “\(selection.title)”: \(reason)"
        case .clipboardUnavailable: "Could not write the conversation to the clipboard."
        }
    }
}
