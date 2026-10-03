import Foundation

/// Wording for a host where no supported CLI was found.
enum NewSessionProviderAvailability {
    static func noCLIFoundMessage(on host: SessionHost, language: AppInterfaceLanguage = AppLocalization.developmentLanguage) -> String {
        let locale = Locale(identifier: language.localizationIdentifier(availableLocalizations: AppLocalization.resourceBundle.localizations))
        let supportedCLINames = ConversationProvider.allCases
            .map(\.executableName)
            .formatted(.list(type: .or).locale(locale))
        return host == .thisMac
            ? AppLocalization.string("No supported CLI found on this Mac. Install \(supportedCLINames), then refresh.", language: language)
            : AppLocalization.string("No supported CLI found on \(host.displayName). Install \(supportedCLINames) there, then refresh.", language: language)
    }
}
