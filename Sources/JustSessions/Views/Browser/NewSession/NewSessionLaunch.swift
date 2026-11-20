enum NewSessionLaunch {
    case cli(ConversationProvider, deletesSessionWhenClosed: Bool)
    case plainTerminal

    init(kind: NewSessionKind, deletesSessionWhenClosed: Bool) {
        switch kind {
        case .cli(let provider): self = .cli(provider, deletesSessionWhenClosed: deletesSessionWhenClosed)
        case .plainTerminal: self = .plainTerminal
        }
    }
}
