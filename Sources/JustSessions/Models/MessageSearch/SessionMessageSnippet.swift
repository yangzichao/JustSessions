import Foundation

struct SessionMessageSnippet: Sendable, Equatable {
    let leadingText: String
    let matchedText: String
    let trailingText: String

    static let leadingCharacterCount = 24
    static let trailingCharacterCount = 120

    init(leadingText: String, matchedText: String, trailingText: String) {
        self.leadingText = leadingText
        self.matchedText = matchedText
        self.trailingText = trailingText
    }

    init(segment: String, match: Range<String.Index>) {
        let leadingStart =
            segment.index(match.lowerBound, offsetBy: -Self.leadingCharacterCount, limitedBy: segment.startIndex)
            ?? segment.startIndex
        let trailingEnd =
            segment.index(match.upperBound, offsetBy: Self.trailingCharacterCount, limitedBy: segment.endIndex)
            ?? segment.endIndex
        let leadingContext = Self.singleSpaced(segment[leadingStart..<match.lowerBound]).drop(while: \.isWhitespace)
        leadingText = (leadingStart > segment.startIndex ? "…" : "") + leadingContext
        matchedText = Self.singleSpaced(segment[match])
        var trailingContext = Self.singleSpaced(segment[match.upperBound..<trailingEnd])
        while trailingContext.last?.isWhitespace == true { trailingContext.removeLast() }
        trailingText = trailingEnd < segment.endIndex ? trailingContext + "…" : trailingContext
    }

    var text: String { leadingText + matchedText + trailingText }

    private static func singleSpaced(_ text: Substring) -> String {
        var result = ""
        var followsWhitespace = false
        for character in text {
            if character.isWhitespace {
                if !followsWhitespace { result.append(" ") }
                followsWhitespace = true
            } else {
                result.append(character)
                followsWhitespace = false
            }
        }
        return result
    }
}
