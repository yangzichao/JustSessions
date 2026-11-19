import Foundation

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
            return Bundle.preferredLocalizations(from: matchingLanguage, forPreferences: [preference]).first
                ?? matchingLanguage.sorted().first ?? fallback
        }
        return fallback
    }

    private static func supportedIdentifiers(_ localizations: [String]) -> [String] {
        Array(Set(localizations.filter { !$0.isEmpty && $0 != "Base" }.map(canonicalIdentifier))).sorted()
    }
}
