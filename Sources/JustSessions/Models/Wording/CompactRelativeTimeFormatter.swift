import Foundation

/// Short ages for sidebar rows: "now", "5m", "3h", and "2d" within a week, then a short date such as "Sep 3".
enum CompactRelativeTimeFormatter {
    static func string(
        for date: Date,
        relativeTo now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let elapsedSeconds = now.timeIntervalSince(date)
        let secondsPerMinute: TimeInterval = 60
        let secondsPerHour = 60 * secondsPerMinute
        let secondsPerDay = 24 * secondsPerHour

        // A file stamped slightly in the future (clock skew) also reads as "now".
        if elapsedSeconds < secondsPerMinute { return "now" }
        if elapsedSeconds < secondsPerHour { return "\(Int(elapsedSeconds / secondsPerMinute))m" }
        if elapsedSeconds < secondsPerDay { return "\(Int(elapsedSeconds / secondsPerHour))h" }
        if elapsedSeconds < 7 * secondsPerDay { return "\(Int(elapsedSeconds / secondsPerDay))d" }

        let dateStyle = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            return date.formatted(dateStyle.month(.abbreviated).day())
        }
        return date.formatted(dateStyle.year(.twoDigits).month(.defaultDigits).day())
    }
}
