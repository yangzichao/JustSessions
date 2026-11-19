import AppKit
import Combine

@MainActor
final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()

    @Published private(set) var mode: AppAppearanceMode
    private let userDefaults: UserDefaults
    private let setApplicationAppearance: @MainActor (NSAppearance?) -> Void

    init(
        userDefaults: UserDefaults = .standard,
        setApplicationAppearance: @escaping @MainActor (NSAppearance?) -> Void = { NSApp?.appearance = $0 }
    ) {
        self.userDefaults = userDefaults
        self.setApplicationAppearance = setApplicationAppearance
        mode = AppAppearanceMode.load(from: userDefaults)
    }

    func applyToApplication() {
        setApplicationAppearance(mode.nativeAppearance)
    }

    func setMode(_ newMode: AppAppearanceMode) {
        guard newMode != mode else { return }
        newMode.save(to: userDefaults)
        mode = newMode
        applyToApplication()
    }
}
