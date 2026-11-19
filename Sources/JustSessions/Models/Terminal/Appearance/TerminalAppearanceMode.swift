import AppKit

enum TerminalAppearanceMode: String, CaseIterable, Codable, Identifiable {
    case matchApp
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .matchApp: "Match app"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Nil lets the terminal inherit the app's appearance from its window.
    var nativeAppearance: NSAppearance? {
        switch self {
        case .matchApp: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    func usesDarkColors(effectiveAppearance: NSAppearance) -> Bool {
        usesDarkColors(whenAppIsDark: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
    }

    func usesDarkColors(whenAppIsDark appIsDark: Bool) -> Bool {
        switch self {
        case .matchApp: appIsDark
        case .light: false
        case .dark: true
        }
    }
}
