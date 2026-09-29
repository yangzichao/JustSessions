import AppKit
import Combine

/// The app's saved appearance. It is set on `NSApp`, so every window follows it, and terminals that match the app
/// inherit it from their window.
@MainActor
final class AppAppearanceStore: ObservableObject {
    static let shared = AppAppearanceStore()

    @Published private(set) var mode: AppAppearanceMode
    private let userDefaults: UserDefaults
    private let setApplicationAppearance: @MainActor (NSAppearance?) -> Void

    /// The default sets the appearance through `NSApp` rather than `NSApplication.shared`: before launch, `shared`
    /// would create a plain `NSApplication` in place of the one SwiftUI starts.
    init(
        userDefaults: UserDefaults = .standard,
        setApplicationAppearance: @escaping @MainActor (NSAppearance?) -> Void = { NSApp?.appearance = $0 }
    ) {
        self.userDefaults = userDefaults
        self.setApplicationAppearance = setApplicationAppearance
        mode = AppAppearanceMode.load(from: userDefaults)
    }

    /// `JustSessionsAppDelegate` calls this at launch, once `NSApp` exists and before the first window opens.
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
