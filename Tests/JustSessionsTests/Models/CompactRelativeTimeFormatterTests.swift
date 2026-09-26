import Foundation
import Testing
@testable import JustSessions

struct CompactRelativeTimeFormatterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US")
    /// 2026-09-25 12:00:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_790_337_600)

    private func age(secondsAgo: TimeInterval) -> String {
        CompactRelativeTimeFormatter.string(
            for: now.addingTimeInterval(-secondsAgo),
            relativeTo: now,
            calendar: calendar,
            locale: locale
        )
    }

    @Test func showsMinutesHoursAndDaysWithinAWeek() {
        #expect(age(secondsAgo: 0) == "now")
        #expect(age(secondsAgo: 59) == "now")
        #expect(age(secondsAgo: 60) == "1m")
        #expect(age(secondsAgo: 59 * 60 + 59) == "59m")
        #expect(age(secondsAgo: 60 * 60) == "1h")
        #expect(age(secondsAgo: 23 * 60 * 60 + 59 * 60) == "23h")
        #expect(age(secondsAgo: 24 * 60 * 60) == "1d")
        #expect(age(secondsAgo: 7 * 24 * 60 * 60 - 1) == "6d")
    }

    @Test func showsTheDateAfterAWeek() {
        #expect(age(secondsAgo: 7 * 24 * 60 * 60) == "Sep 18")
        #expect(age(secondsAgo: 200 * 24 * 60 * 60) == "Mar 9")
    }

    @Test func includesTheYearForEarlierYears() {
        let lastYear = calendar.date(from: DateComponents(year: 2025, month: 9, day: 3, hour: 8))!
        #expect(CompactRelativeTimeFormatter.string(for: lastYear, relativeTo: now, calendar: calendar, locale: locale) == "9/3/25")
    }

    @Test func treatsFutureTimestampsAsNow() {
        #expect(age(secondsAgo: -90) == "now")
    }
}
