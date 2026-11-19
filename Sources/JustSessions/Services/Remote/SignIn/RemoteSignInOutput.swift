import Foundation

/// What a sign-in command printed since it was last answered, as plain text: the terminal on the host adds carriage
/// returns, escape sequences such as colors, and echoes an answer typed with its echo on, which this leaves out. Once
/// the command waits, its last line is the question and the lines before it are its context.
struct RemoteSignInOutput {
    /// How many lines before the question its context keeps.
    static let contextLineLimit = 12
    /// How many lines a failure's message keeps.
    static let failureLineLimit = 8

    /// What was printed since the last answer.
    private(set) var text = ""
    /// The last lines printed over the whole run, for a failure's message.
    private(set) var recentLines: [String] = []
    private var currentLine = ""
    private var undecodedBytes = Data()
    private var escapeState = EscapeState.none
    /// What the host's terminal would echo of the last answer, swallowed while the output matches it.
    private var pendingEcho: [Character] = []
    private var swallowedEcho = ""

    private enum EscapeState {
        case none
        /// After ESC.
        case escape
        /// In `ESC [`, until its final byte.
        case controlSequence
        /// In `ESC ]`, until BEL or `ESC \`.
        case operatingSystemCommand
        case operatingSystemCommandEscape
    }

    /// Whether the last line was left without a newline, as a prompt that reads on the same line is.
    var endsMidLine: Bool {
        !lastLine(of: text, includingCompleteLines: false).isEmpty
    }

    /// The line the command waits after: the last one with text, finished or not.
    var question: String? {
        let line = lastLine(of: text, includingCompleteLines: true)
        return line.isEmpty ? nil : line
    }

    /// The lines before the question, up to `contextLineLimit`; nil when there are none.
    var context: String? {
        var lines = nonEmptyLines(of: text)
        guard !lines.isEmpty else { return nil }
        lines.removeLast()
        let kept = lines.suffix(Self.contextLineLimit).joined(separator: "\n")
        return kept.isEmpty ? nil : kept
    }

    /// The command's last lines, for a message saying why it failed; nil when it printed nothing.
    var failureText: String? {
        let lines = (recentLines + [currentLine]).map(Self.trimmedTrailing).filter { !$0.isEmpty }
        let kept = lines.suffix(Self.failureLineLimit).joined(separator: "\n")
        return kept.isEmpty ? nil : kept
    }

    mutating func append(_ data: Data) {
        undecodedBytes.append(data)
        // A character can arrive split between reads; its last bytes come with the next.
        var decodable = undecodedBytes.count
        while decodable > max(0, undecodedBytes.count - 4) {
            if let decoded = String(data: undecodedBytes.prefix(decodable), encoding: .utf8) {
                undecodedBytes.removeFirst(decodable)
                for character in decoded { append(character) }
                return
            }
            decodable -= 1
        }
        // Not UTF-8 at all: show what can be shown rather than waiting forever.
        let decoded = String(decoding: undecodedBytes, as: UTF8.self)
        undecodedBytes.removeAll()
        for character in decoded { append(character) }
    }

    /// Starts a new question's text, and expects the host's terminal to echo `answer`.
    mutating func noteAnswered(_ answer: String) {
        text = ""
        pendingEcho = Array(answer + "\n")
        swallowedEcho = ""
    }

    private mutating func append(_ character: Character) {
        switch escapeState {
        case .escape:
            escapeState = character == "[" ? .controlSequence : character == "]" ? .operatingSystemCommand : .none
            return
        case .controlSequence:
            if let ascii = character.asciiValue, (0x40...0x7E).contains(ascii) { escapeState = .none }
            return
        case .operatingSystemCommand:
            if character == "\u{07}" { escapeState = .none } else if character == "\u{1B}" { escapeState = .operatingSystemCommandEscape }
            return
        case .operatingSystemCommandEscape:
            escapeState = character == "\\" ? .none : .operatingSystemCommand
            return
        case .none:
            break
        }
        switch character {
        case "\u{1B}":
            escapeState = .escape
        case "\r", "\r\n":
            if character == "\r\n" { appendVisible("\n") }
        case "\n", "\t":
            appendVisible(character)
        case "\u{08}", "\u{7F}":
            if !text.isEmpty, text.last != "\n" { text.removeLast() }
            if !currentLine.isEmpty { currentLine.removeLast() }
        default:
            if let scalar = character.unicodeScalars.first, scalar.properties.generalCategory == .control { return }
            appendVisible(character)
        }
    }

    private mutating func appendVisible(_ character: Character) {
        if !pendingEcho.isEmpty {
            if character == pendingEcho.first {
                pendingEcho.removeFirst()
                swallowedEcho.append(character)
                return
            }
            // Not an echo after all, as from a command that reads with its echo off: what was held back is output.
            let heldBack = swallowedEcho
            pendingEcho = []
            swallowedEcho = ""
            for heldCharacter in heldBack { appendVisible(heldCharacter) }
        }
        text.append(character)
        if character == "\n" {
            if !currentLine.trimmingCharacters(in: .whitespaces).isEmpty { recentLines.append(currentLine) }
            if recentLines.count > Self.failureLineLimit { recentLines.removeFirst(recentLines.count - Self.failureLineLimit) }
            currentLine = ""
        } else {
            currentLine.append(character)
        }
    }

    private func nonEmptyLines(of text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Self.trimmedTrailing(String($0)) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private func lastLine(of text: String, includingCompleteLines: Bool) -> String {
        if includingCompleteLines { return nonEmptyLines(of: text).last?.trimmingCharacters(in: .whitespaces) ?? "" }
        guard let lastNewline = text.lastIndex(of: "\n") else { return text.trimmingCharacters(in: .whitespaces) }
        return text[text.index(after: lastNewline)...].trimmingCharacters(in: .whitespaces)
    }

    private static func trimmedTrailing(_ line: String) -> String {
        String(line.reversed().drop(while: { $0 == " " || $0 == "\t" }).reversed())
    }
}
