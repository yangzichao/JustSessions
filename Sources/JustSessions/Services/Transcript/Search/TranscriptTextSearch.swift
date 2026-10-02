import Foundation

enum TranscriptTextSearch {
    /// Literal, non-overlapping matches. UTF-16 ranges also work with AppKit's text layout.
    static func ranges(of query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        var ranges: [NSRange] = []
        var remainingRange = text.startIndex..<text.endIndex
        while let match = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: remainingRange) {
            guard !match.isEmpty else { break }
            ranges.append(NSRange(match, in: text))
            remainingRange = match.upperBound..<text.endIndex
        }
        return ranges
    }
}
