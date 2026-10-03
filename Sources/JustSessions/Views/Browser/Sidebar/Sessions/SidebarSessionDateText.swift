import Combine
import Foundation

/// The last-activity date text a session row's tooltip shows, exactly as
/// `Date.formatted(date: .abbreviated, time: .shortened)` spells it. Formatting builds the text through ICU every
/// time, and scrolling realizes hundreds of rows per screen, so each distinct date is formatted once and kept.
@MainActor
final class SidebarSessionDateText {
    static let shared = SidebarSessionDateText()

    private static let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
    /// Big enough for every session a sidebar realistically lists; emptied rather than evicted when passed, so the
    /// cache cannot grow with years of changing dates.
    private static let maximumCachedDates = 4_096

    private var textsByDate: [Date: String] = [:]
    private var localeOrTimeZoneChanges: AnyCancellable?

    /// How many distinct dates are kept; the tests check that the notifications below empty the cache.
    var cachedTextCount: Int { textsByDate.count }

    init(notificationCenter: NotificationCenter = .default) {
        // The style formats with the current locale and time zone, so either changing invalidates every kept text.
        localeOrTimeZoneChanges = notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .merge(with: notificationCenter.publisher(for: .NSSystemTimeZoneDidChange))
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.textsByDate.removeAll() }
    }

    func text(for date: Date) -> String {
        if let text = textsByDate[date] { return text }
        if textsByDate.count >= Self.maximumCachedDates { textsByDate.removeAll() }
        let text = date.formatted(Self.style)
        textsByDate[date] = text
        return text
    }
}
