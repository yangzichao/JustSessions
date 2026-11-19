import Foundation

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
