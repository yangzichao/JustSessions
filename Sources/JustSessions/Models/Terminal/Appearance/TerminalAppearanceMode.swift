import AppKit

enum TerminalAppearanceMode: String, CaseIterable, Codable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "Follow system"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var nativeAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    func usesDarkPalette(systemAppearance: NSAppearance) -> Bool {
        switch self {
        case .system: systemAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        case .light: false
        case .dark: true
        }
    }
}
