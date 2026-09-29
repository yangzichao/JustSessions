import Combine
import Foundation

/// The theme chosen in Settings. Each window puts it in its views' environment, and terminals restyle from it.
@MainActor
final class AppThemeStore: ObservableObject {
    static let shared = AppThemeStore()

    @Published private(set) var theme: AppTheme
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        theme = AppTheme.load(from: userDefaults)
    }

    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        newTheme.save(to: userDefaults)
        theme = newTheme
    }
}
