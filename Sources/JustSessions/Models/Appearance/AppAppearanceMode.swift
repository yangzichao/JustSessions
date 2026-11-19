import AppKit

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let userDefaultsKey = "appAppearance"

    var id: String { rawValue }

    /// Nil lets the app follow the Mac's appearance.
    var nativeAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    static func load(from userDefaults: UserDefaults) -> Self {
        userDefaults.string(forKey: userDefaultsKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    func save(to userDefaults: UserDefaults) {
        userDefaults.set(rawValue, forKey: Self.userDefaultsKey)
    }
}
