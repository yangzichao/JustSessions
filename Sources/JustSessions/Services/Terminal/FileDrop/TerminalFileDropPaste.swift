import Foundation

/// Each path goes as its own paste. Claude Code and Codex attach a pasted image path as the image, and Codex only when
/// the paste holds a single path. A shell reads the pastes as the paths separated by spaces.
enum TerminalFileDropPaste {
    static func bytes(forPaths paths: [String], isBracketed: Bool) -> [UInt8] {
        paths.flatMap { path in
            let pastedText = Array((escapedPath(path) + " ").utf8)
            guard isBracketed else { return pastedText }
            return bracketedPasteStart + pastedText + bracketedPasteEnd
        }
    }

    /// Claude Code and Codex remove the backslashes, as a shell does. Other characters, such as Chinese letters or the
    /// narrow no-break space in a screenshot's name, mean nothing to a shell and stay as they are.
    static func escapedPath(_ path: String) -> String {
        var escapedPath = ""
        for scalar in path.unicodeScalars {
            if scalar.isASCII && !asciiCharactersTypedAsIs.contains(scalar) { escapedPath.append("\\") }
            escapedPath.unicodeScalars.append(scalar)
        }
        return escapedPath
    }

    /// `CSI 200 ~` and `CSI 201 ~`, which SwiftTerm's own paste sends around the text.
    static let bracketedPasteStart: [UInt8] = Array("\u{1B}[200~".utf8)
    static let bracketedPasteEnd: [UInt8] = Array("\u{1B}[201~".utf8)
    private static let asciiCharactersTypedAsIs = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-+,:@%"
    )
}
