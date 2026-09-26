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

    /// The shared formatters give the same dates as formatters made for each call, as the app used to make them.
    @Test(arguments: timestamps)
    func parsesLikeFormattersMadeForEachCall(_ text: String) {
        let fractionalSecondsFormatter = ISO8601DateFormatter()
        fractionalSecondsFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expectedDate = fractionalSecondsFormatter.date(from: text) ?? ISO8601DateFormatter().date(from: text)

        #expect(ISO8601TimestampParser.shared.date(from: text) == expectedDate)
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
