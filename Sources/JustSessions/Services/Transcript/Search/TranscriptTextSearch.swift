import Foundation

enum TranscriptTextSearch {
    private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

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

    static func firstRange(of query: String, in text: String) -> Range<String.Index>? {
        guard !query.isEmpty, let match = text.range(of: query, options: options), !match.isEmpty else { return nil }
        return match
    }
}
