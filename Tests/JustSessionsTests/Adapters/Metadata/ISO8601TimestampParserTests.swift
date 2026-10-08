import Foundation
import Testing
@testable import JustSessions

struct ISO8601TimestampParserTests {
    /// Formats the CLIs write, and ones they do not, which must stay unparsed.
    static let timestamps = [
        "2026-09-24T10:00:00Z",
        "2026-09-24T10:00:00.1Z",
        "2026-09-24T10:00:00.123Z",
        "2026-09-24T10:00:00.123456Z",
        "2026-09-24T10:00:00.123456789Z",
        "2026-09-24T10:00:00+00:00",
        "2026-09-24T10:00:00.250-07:00",
        "2026-09-24T10:00:00",
        "2026-09-24 10:00:00Z",
        "2026-09-24",
        "not a date",
        "",
    ]

    /// The parser accepts and rejects what `ISO8601DateFormatter`, which the app used before, does, and gives the same
    /// instants to the millisecond that formatter kept.
    @Test(arguments: timestamps)
    func parsesTheSameInstantsAsISO8601DateFormatter(_ text: String) {
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let formatterDate = fractionalSecondsFormatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)
        let date = ISO8601TimestampParser.shared.date(from: text)

        #expect((date == nil) == (formatterDate == nil))
        if let date, let formatterDate {
            #expect(abs(date.timeIntervalSince(formatterDate)) < 0.001)
        }
    }

    @Test func keepsFractionsFinerThanAMillisecond() throws {
        let wholeSecond = try #require(ISO8601TimestampParser.shared.date(from: "2026-09-24T10:00:00Z"))
        let date = try #require(ISO8601TimestampParser.shared.date(from: "2026-09-24T10:00:00.123456Z"))

        #expect(abs(date.timeIntervalSince(wholeSecond) - 0.123456) < 0.000_001)
    }

    @Test func everyTaskGetsTheSameDatesFromTheSharedParser() async {
        let texts = (0..<2_000).map { index in
            String(format: "2026-09-24T%02d:%02d:%02d.%03dZ", index / 3_600 % 24, index / 60 % 60, index % 60, index % 1_000)
        }
        let expectedDates = texts.map { ISO8601TimestampParser().date(from: $0) }
        #expect(!expectedDates.contains(nil))

        let datesPerTask = await withTaskGroup(of: [Date?].self) { group in
            for _ in 0..<8 {
                group.addTask { texts.map { ISO8601TimestampParser.shared.date(from: $0) } }
            }
            var collectedDates: [[Date?]] = []
            for await dates in group { collectedDates.append(dates) }
            return collectedDates
        }

        #expect(datesPerTask.count == 8)
        #expect(datesPerTask.allSatisfy { $0 == expectedDates })
    }
}
