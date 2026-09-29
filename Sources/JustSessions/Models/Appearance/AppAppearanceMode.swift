import AppKit

/// Light or Dark for the whole app, or following the Mac. Every window, sheet, and menu takes it on, and so does
/// every terminal set to match the app.
enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let userDefaultsKey = "appAppearance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Nil lets the app follow the Mac's appearance.
    var nativeAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    /// The saved mode, or System when nothing is saved or the saved value is not a mode.
    static func load(from userDefaults: UserDefaults) -> Self {
        userDefaults.string(forKey: userDefaultsKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
