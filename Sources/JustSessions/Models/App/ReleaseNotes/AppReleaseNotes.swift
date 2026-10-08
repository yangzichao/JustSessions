import Foundation

/// Editorial release history shared with the website, GitHub, and Sparkle. Copy is kept in the release catalog,
/// rather than extracted as UI labels, so each version's English and Chinese notes stay together.
struct AppReleaseNotes: Decodable, Identifiable, Sendable {
    let version: String
    let publishedOn: String
    let title: ReleaseNoteText
    let sections: [Section]

    var id: String { version }

    struct Section: Decodable, Sendable {
        let kind: Kind
        let items: [ReleaseNoteText]

        enum Kind: String, Decodable, Sendable {
            case new, improved, fixed
        }
    }

    /// A release date is a calendar day, so changing the Mac's time zone must not shift it to the previous day.
    func formattedDate(locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: publishedOn) else { return publishedOn }
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
