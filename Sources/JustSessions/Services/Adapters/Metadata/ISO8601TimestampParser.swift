import Foundation

/// Parses the ISO 8601 timestamps the CLIs write, with or without fractional seconds.
/// Creating an `ISO8601DateFormatter` costs several times more than parsing with one, and a transcript holds a
/// timestamp per record, so the formatters are made once and shared. Foundation does not document them as
/// thread-safe, so a lock guards them.
final class ISO8601TimestampParser: @unchecked Sendable {
    static let shared = ISO8601TimestampParser()

    private let lock = NSLock()
    private let fractionalSecondsFormatter: ISO8601DateFormatter
    private let wholeSecondsFormatter = ISO8601DateFormatter()

    init() {
        fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    func date(from text: String) -> Date? {
        lock.withLock {
            fractionalSecondsFormatter.date(from: text) ?? wholeSecondsFormatter.date(from: text)
        }
    }
}
