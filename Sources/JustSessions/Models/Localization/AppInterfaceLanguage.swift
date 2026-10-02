import Foundation

/// A resource identifier, rather than one enum case per translation. Adding a localization needs no Swift edits.
struct AppInterfaceLanguage: Hashable, Identifiable, Sendable {
    static let followSystem = AppInterfaceLanguage(identifier: nil)
    static let userDefaultsKey = "interfaceLanguage"

    let identifier: String?
    var id: String { identifier ?? "followSystem" }

    init(identifier: String?) {
        self.identifier = identifier.map(Self.canonicalIdentifier)
    }

    static func canonicalIdentifier(_ identifier: String) -> String {
        Locale.canonicalLanguageIdentifier(from: identifier)
    }

    /// Use each language's own name so users can always recognize the choice they need.
    var nativeName: String {
        guard let identifier else { return "Follow System" }
        let locale = Locale(identifier: identifier)
        return (locale.localizedString(forIdentifier: identifier) ?? identifier).capitalized(with: locale)
    }

    static func choices(availableLocalizations: [String]) -> [Self] {
        [.followSystem] + supportedIdentifiers(availableLocalizations).sorted().map { Self(identifier: $0) }
    }

    func localizationIdentifier(
        availableLocalizations: [String],
        preferredLanguages: [String] = Locale.preferredLanguages,
        developmentLocalization: String = "en"
    ) -> String {
        let supported = Self.supportedIdentifiers(availableLocalizations)
        let developmentIdentifier = Self.canonicalIdentifier(developmentLocalization)
        let fallback = supported.contains(developmentIdentifier) ? developmentIdentifier : supported.sorted().first ?? developmentIdentifier
        if let identifier, supported.contains(identifier) { return identifier }
        guard identifier == nil else { return fallback }
        for preference in preferredLanguages {
            let languageCode = Locale(identifier: preference).language.languageCode
            let matchingLanguage = supported.filter { Locale(identifier: $0).language.languageCode == languageCode }
            guard !matchingLanguage.isEmpty else { continue }
            // Foundation chooses the best region/script. If only another script is translated, use that
            // language rather than unexpectedly falling back to English. This rule applies to every language.
            return Bundle.preferredLocalizations(from: matchingLanguage, forPreferences: [preference]).first
                ?? matchingLanguage.sorted().first ?? fallback
        }
        return fallback
    }

    private static func supportedIdentifiers(_ localizations: [String]) -> [String] {
        Array(Set(localizations.filter { !$0.isEmpty && $0 != "Base" }.map(canonicalIdentifier))).sorted()
    }
}
