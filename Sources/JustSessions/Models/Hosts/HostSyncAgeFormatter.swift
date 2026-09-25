import Foundation

/// How long ago an SSH host's sessions were last copied, for its sidebar heading: "synced just now",
/// "synced 5m ago", and after a week a date such as "synced Sep 3".
enum HostSyncAgeFormatter {
    static func string(
        forSyncedAt syncDate: Date,
        relativeTo now: Date,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let elapsedSeconds = now.timeIntervalSince(syncDate)
        if elapsedSeconds < 60 { return "synced just now" }
        let age = CompactRelativeTimeFormatter.string(for: syncDate, relativeTo: now, calendar: calendar, locale: locale)
        return elapsedSeconds < 7 * 24 * 60 * 60 ? "synced \(age) ago" : "synced \(age)"
    }
}
