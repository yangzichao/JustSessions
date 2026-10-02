import Combine
import Foundation

@MainActor
final class AppLanguageStore: ObservableObject {
    static let shared = AppLanguageStore()
    static let userDefaultsKey = AppInterfaceLanguage.userDefaultsKey

    @Published private(set) var language: AppInterfaceLanguage
    private let userDefaults: UserDefaults
    let choices: [AppInterfaceLanguage]
    private let developmentLocalization: String
    private var systemLocaleObservation: AnyCancellable?

    var locale: Locale {
        Locale(identifier: language.localizationIdentifier(
            availableLocalizations: choices.compactMap(\.identifier),
            developmentLocalization: developmentLocalization
        ))
    }

    init(
        userDefaults: UserDefaults = .standard,
        bundle: Bundle = AppLocalization.resourceBundle,
        notificationCenter: NotificationCenter = .default
    ) {
        self.userDefaults = userDefaults
        let availableChoices = AppInterfaceLanguage.choices(availableLocalizations: bundle.localizations)
        choices = availableChoices
        developmentLocalization = bundle.developmentLocalization ?? "en"
        let savedChoice = userDefaults.string(forKey: Self.userDefaultsKey).map { AppInterfaceLanguage(identifier: $0) }
        language = savedChoice.flatMap { availableChoices.contains($0) ? $0 : nil } ?? .followSystem
        if userDefaults.object(forKey: Self.userDefaultsKey) != nil && language == .followSystem {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
        }
        systemLocaleObservation = notificationCenter.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.language == .followSystem else { return }
                self.objectWillChange.send()
            }
    }

    func setLanguage(_ language: AppInterfaceLanguage) {
        guard choices.contains(language), self.language != language else { return }
        if let identifier = language.identifier {
            userDefaults.set(identifier, forKey: Self.userDefaultsKey)
        } else {
            userDefaults.removeObject(forKey: Self.userDefaultsKey)
        }
        self.language = language
    }
}
