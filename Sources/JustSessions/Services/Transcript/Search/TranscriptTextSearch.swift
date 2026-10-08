import Foundation

enum TranscriptTextSearch {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Literal, non-overlapping matches. UTF-16 ranges also work with AppKit's text layout.
    static func ranges(of query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        var ranges: [NSRange] = []
        var remainingRange = text.startIndex..<text.endIndex
        while let match = text.range(of: query, options: options, range: remainingRange) {
            guard !match.isEmpty else { break }
            ranges.append(NSRange(match, in: text))
            remainingRange = match.upperBound..<text.endIndex
        }
        return ranges
    }

    /// The first of `ranges(of:in:)`, as a range of `text`.
    static func firstRange(of query: String, in text: String) -> Range<String.Index>? {
        guard !query.isEmpty, let match = text.range(of: query, options: options), !match.isEmpty else { return nil }
        return match
    }
}
