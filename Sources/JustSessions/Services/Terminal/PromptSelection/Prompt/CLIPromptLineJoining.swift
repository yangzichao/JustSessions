/// A CLI draws a line it wrapped and a line you broke the same way, so the rows alone don't say which it was. Every
/// supported CLI wraps at a space, which it leaves out of the rows.
enum CLIPromptLineJoining {
    static func text(of lines: [CLIPromptLine], wrapWidth: Int) -> String {
        guard var text = lines.first?.text else { return "" }
        for (previousLine, line) in zip(lines, lines.dropFirst()) {
            text += rowEnd(of: previousLine, before: line, wrapWidth: wrapWidth).separator
            text += line.text
        }
        return text
    }

    private static func rowEnd(of previousLine: CLIPromptLine, before line: CLIPromptLine, wrapWidth: Int) -> PromptRowEnd {
        let nextRowIsEmptyOrIndented = line.text.first?.isWhitespace ?? true
        if previousLine.text.isEmpty || nextRowIsEmptyOrIndented
            || nextRowsFirstWord(of: line, wouldHaveFitAfter: previousLine, wrapWidth: wrapWidth)
        {
            return .lineYouBroke
        }
        return previousLine.cellCount >= wrapWidth ? .wrapInsideAWord : .wrapAtASpace
    }

    private static func nextRowsFirstWord(
        of line: CLIPromptLine, wouldHaveFitAfter previousLine: CLIPromptLine, wrapWidth: Int
    ) -> Bool {
        let firstWordCellCount = TerminalScreenRow(String(line.text.prefix { !$0.isWhitespace })).textWidth
        let spaceBeforeTheWord = 1
        return previousLine.cellCount + spaceBeforeTheWord + firstWordCellCount <= wrapWidth
    }
}

private enum PromptRowEnd {
    case lineYouBroke
    case wrapInsideAWord
    case wrapAtASpace

    var separator: String {
        switch self {
        case .lineYouBroke: "\n"
        case .wrapInsideAWord: ""
        case .wrapAtASpace: " "
        }
    }
}
