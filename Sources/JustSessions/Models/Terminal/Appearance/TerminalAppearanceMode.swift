import AppKit

enum TerminalAppearanceMode: String, CaseIterable, Codable, Identifiable {
    /// Takes on the app's appearance, whether that follows the Mac or is set to Light or Dark.
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

    /// Whether the terminal takes the dark version of the theme's colors.
    func usesDarkColors(effectiveAppearance: NSAppearance) -> Bool {
        switch self {
        case .matchApp: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        case .light: false
        case .dark: true
        }
    }
}
