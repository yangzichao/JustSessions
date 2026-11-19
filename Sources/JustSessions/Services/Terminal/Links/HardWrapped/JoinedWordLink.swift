/// The URL or path in a word that holds a given character, by Ghostty's rules, cut down to a word without spaces. A URL runs from its scheme over the characters a URL may hold; a path runs over the characters
/// a path may hold and has a `/`. Neither ends in `.` or `,`, a path doesn't end in `:`, and a URL keeps a closing
/// bracket only when it also opened one, as `(https://example.com)` shows.
enum JoinedWordLink {
    static func linkRange(in word: [Character], holding index: Int) -> Range<Int>? {
        guard word.indices.contains(index) else { return nil }
        if let urlRange = urlRange(in: word, holding: index) { return urlRange }
        return pathRange(in: word, holding: index)
    }

    /// Ghostty's schemes, longest first where one begins another.
    private static let urlSchemes = [
        "https://", "http://", "mailto:", "ftp://", "file:", "ssh://", "ssh:", "git://", "tel:", "magnet:", "ipfs://",
        "ipns://", "gemini://", "gopher://", "news:",
    ].map(Array.init)
    private static let urlPunctuation = Set("-.~:/?#@!$&*+,;=%_()[]")
    private static let pathPunctuation = Set("-.~:/?#@!$&*+;=%_")

    private static func urlRange(in word: [Character], holding index: Int) -> Range<Int>? {
        for start in 0...index {
            guard let scheme = urlSchemes.first(where: { word[start...].starts(with: $0) }) else { continue }
            var end = start + scheme.count
            while end < word.count, isURLCharacter(word[end]) { end += 1 }
            end = trimmingURLEnd(of: word, from: start, to: end)
            if end > start + scheme.count, index < end { return start..<end }
        }
        return nil
    }

    private static func pathRange(in word: [Character], holding index: Int) -> Range<Int>? {
        guard isPathCharacter(word[index]) else { return nil }
        var start = index
        while start > 0, isPathCharacter(word[start - 1]) { start -= 1 }
        var end = index + 1
        while end < word.count, isPathCharacter(word[end]) { end += 1 }
        while end > start, [".", ":"].contains(word[end - 1]) { end -= 1 }
        guard index < end, word[start..<end].contains("/") else { return nil }
        return start..<end
    }

    private static func trimmingURLEnd(of word: [Character], from start: Int, to end: Int) -> Int {
        var end = end
        while end > start {
            let last = word[end - 1]
            let url = word[start..<end]
            let closesUnopenedBracket =
                (last == ")" && url.count { $0 == "(" } < url.count { $0 == ")" })
                || (last == "]" && url.count { $0 == "[" } < url.count { $0 == "]" })
            guard last == "." || last == "," || closesUnopenedBracket else { break }
            end -= 1
        }
        return end
    }

    private static func isURLCharacter(_ character: Character) -> Bool {
        isWordCharacter(character) || urlPunctuation.contains(character)
    }

    private static func isPathCharacter(_ character: Character) -> Bool {
        isWordCharacter(character) || pathPunctuation.contains(character)
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }
}
