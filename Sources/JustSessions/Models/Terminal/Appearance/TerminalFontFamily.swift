import AppKit

enum TerminalFontFamily: String, CaseIterable, Codable, Identifiable {
    case system
    case menlo
    case monaco

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System Monospaced"
        case .menlo: "Menlo"
        case .monaco: "Monaco"
        }
    }

    func font(size: CGFloat) -> NSFont {
        let fallback = NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
        switch self {
        case .system: return fallback
        case .menlo: return NSFont(name: "Menlo-Regular", size: size) ?? fallback
        case .monaco: return NSFont(name: "Monaco", size: size) ?? fallback
        }
    }
}
