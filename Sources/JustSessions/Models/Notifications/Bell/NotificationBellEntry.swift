import Foundation

struct NotificationBellEntry: Identifiable, Equatable {
    let source: SessionAttentionSource
    let reason: SessionAttentionReason
    let waitingSince: Date?
    let sessionTitle: String
    let provider: ConversationProvider
    let projectName: String

    var id: SessionAttentionSource { source }
}

extension Array where Element == NotificationBellEntry {
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
