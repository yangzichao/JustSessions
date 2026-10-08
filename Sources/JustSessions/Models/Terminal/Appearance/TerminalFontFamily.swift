import AppKit

/// The terminal's font: the system's monospaced font, or an installed family chosen by name. An installed family draws
/// Nerd Font icons it lacks with the bundled symbols font; see `TerminalSymbolsFont`.
enum TerminalFontFamily: Hashable {
    case system
    case named(String)

    /// A family that is no longer installed, as after its font is removed, gives the system's monospaced font.
    func font(size: CGFloat) -> NSFont {
        guard case .named(let family) = self,
              let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: Self.regularWeight, size: size) else {
            return Self.systemFont(size: size)
        }
        return TerminalSymbolsFont.addingFallback(to: font)
    }

    /// macOS ignores fallback fonts for its system fonts, so this one gets no symbols fallback. With the symbols font
    /// registered, macOS's own fallback still finds the icons in the supplementary Private Use Areas, such as
    /// Material Design's, but not the Powerline separators and most other icons.
    private static func systemFont(size: CGFloat) -> NSFont {
        TerminalSymbolsFont.register()
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// A regular face on `NSFontManager`'s weight scale, which runs from 0 to 15.
    private static let regularWeight = 5
}

extension TerminalFontFamily: Codable {
    /// Saved as the family's name, or as `system`. Versions that offered only three fonts saved `menlo` or `monaco`.
    private static let systemValue = "system"
    private static let earlierFamilyNames = ["menlo": "Menlo", "monaco": "Monaco"]

    init(from decoder: any Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value == Self.systemValue {
            self = .system
        } else {
            self = .named(Self.earlierFamilyNames[value] ?? value)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .system: try container.encode(Self.systemValue)
        case .named(let family): try container.encode(family)
        }
    }
}
