import Foundation

struct ReleaseNoteText: Decodable, Sendable {
    let english: String
    let simplifiedChinese: String

    private enum CodingKeys: String, CodingKey {
        case english = "en"
        case simplifiedChinese = "zh-Hans"
    }

    func localized(for locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? simplifiedChinese : english
    }
}
