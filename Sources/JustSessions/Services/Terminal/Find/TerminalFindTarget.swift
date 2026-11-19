/// What ⌘F searches in a tab. A CLI tab's earlier output is mostly beyond the terminal: each CLI runs in tmux, whose
/// client keeps the terminal on the alternate screen, where neither engine keeps scrollback, and a CLI drawing on the
/// alternate screen itself, as Codex does, leaves no history in tmux either. Its conversation holds all of it, for any
/// CLI, screen mode, host, and engine. So a tab linked to a session finds in its conversation, and only the others, a
/// plain terminal or a CLI tab not linked yet, find in the terminal.
enum TerminalFindTarget: Equatable {
    case conversation(Conversation)
    case terminal

    @MainActor
    init(tab: TerminalSession) {
        if let conversation = tab.conversation {
            self = .conversation(conversation)
        } else {
            self = .terminal
        }
    }
}
