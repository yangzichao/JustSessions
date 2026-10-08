import Foundation

/// Searched text as typed, without surrounding whitespace, and folded the way session text is for the byte search.
struct SessionMessageQuery: Sendable, Equatable {
    let text: String
    let foldedBytes: [UInt8]

    init?(_ typedText: String) {
        let text = typedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        self.text = text
        foldedBytes = Array(Self.folded(text).utf8)
    }

    /// Case and accents aside, as Find matches.
    static func folded(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
