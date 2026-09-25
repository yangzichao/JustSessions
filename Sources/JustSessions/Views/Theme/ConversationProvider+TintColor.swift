import SwiftUI

extension ConversationProvider {
    /// The CLI's hue from the brand palette (Branding/README.md), a little lighter in dark mode so it keeps its contrast.
    var tintColor: Color {
        switch self {
        case .claude: .adaptive(light: 0xFF8A1F, dark: 0xFF9C45)
        case .codex: .adaptive(light: 0x2F6BFF, dark: 0x5C8CFF)
        case .antigravity: .adaptive(light: 0xA64DF0, dark: 0xBA78F5)
        }
    }

    /// A deeper shade of the hue for filled buttons, so white text on it stays readable in both appearances.
    var emphasisTintColor: Color {
        switch self {
        case .claude: .adaptive(light: 0xE0700F, dark: 0xD9691A)
        case .codex: .adaptive(light: 0x2F6BFF, dark: 0x3A6DF0)
        case .antigravity: .adaptive(light: 0x9A3FE6, dark: 0x9447E0)
        }
    }
}
