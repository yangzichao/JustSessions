enum CLIPromptLayout: Equatable {
    case claudeCode
    case codex
    case openCode
    case pi
    case antigravity

    init?(provider: ConversationProvider) {
        switch provider {
        case .claude: self = .claudeCode
        case .codex: self = .codex
        case .opencode: self = .openCode
        case .pi: self = .pi
        case .antigravity: self = .antigravity
        case .kiro: return nil
        }
    }

    func prompt(on screen: TerminalScreen) -> CLIPrompt? {
        guard screen.rows.indices.contains(screen.cursor.row) else { return nil }
        switch self {
        case .claudeCode: return RuledPromptRecognizer.claudeCode.prompt(on: screen)
        case .codex: return CodexPromptRecognizer.prompt(on: screen)
        case .openCode: return OpenCodePromptRecognizer.prompt(on: screen)
        case .pi: return RuledPromptRecognizer.pi.prompt(on: screen)
        case .antigravity: return RuledPromptRecognizer.antigravity.prompt(on: screen)
        }
    }
}

extension CLIPrompt {
    init?(lines: [CLIPromptLine], wrapWidth: Int, caret: TerminalCellPosition, isPlaceholder: (String) -> Bool) {
        if lines.count == 1, let line = lines.first, caret == TerminalCellPosition(column: line.startColumn, row: line.row),
            isPlaceholder(line.text)
        {
            return nil
        }
        self.init(lines: lines, wrapWidth: wrapWidth, caretRow: caret.row)
    }
}
