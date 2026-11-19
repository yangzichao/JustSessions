import Foundation

/// A session the notification bell lists, because its CLI waits on you.
struct NotificationBellEntry: Identifiable, Equatable {
    let source: SessionAttentionSource
    let reason: SessionAttentionReason
    /// Nil until an activity sync of the tab's window has seen the wait, such as just after the tab moved there.
    let waitingSince: Date?
    let sessionTitle: String
    let provider: ConversationProvider
    let projectName: String

    var id: SessionAttentionSource { source }
}

extension Array where Element == NotificationBellEntry {
    /// The wait that started last first, and waits not timed yet at the end. Waits that started together stay in
    /// title order, so rows don't swap places between redraws.
    func sortedNewestFirst() -> [NotificationBellEntry] {
        sorted { first, second in
            switch (first.waitingSince, second.waitingSince) {
            case (let firstStart?, let secondStart?) where firstStart != secondStart:
                return firstStart > secondStart
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                let titleOrder = first.sessionTitle.localizedStandardCompare(second.sessionTitle)
                guard titleOrder == .orderedSame else { return titleOrder == .orderedAscending }
                return first.source.notificationIdentifier < second.source.notificationIdentifier
            }
        }
    }
}
