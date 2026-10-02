enum ConversationExportFormat: Sendable {
    case markdown
    case plainText

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        }
    }
}
