import Foundation

/// Parses the ISO 8601 timestamps the CLIs write, with or without fractional seconds.
/// A transcript holds a timestamp per record, and message search reads several sessions at once. `Date.ISO8601FormatStyle`
/// parses about 50 times faster than `ISO8601DateFormatter`, which goes through ICU, and as a value it is shared across
/// threads without a lock. Unlike the formatter, it keeps fractions finer than a millisecond.
final class ISO8601TimestampParser: Sendable {
    static let shared = ISO8601TimestampParser()

    private let fractionalSecondsStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private let wholeSecondsStyle = Date.ISO8601FormatStyle()

    func date(from text: String) -> Date? {
        (try? fractionalSecondsStyle.parse(text)) ?? (try? wholeSecondsStyle.parse(text))
    }
}
