import SwiftUI

extension ConversationProvider {
    /// The CLI's hue for its icon and the wash behind its selected row (see `tintHexColor`).
    var tintColor: Color {
        .adaptive(tintHexColor)
    }

    /// The CLI's hue for text, darkened or lightened until it is readable on the theme's surfaces.
    var textColor: ThemeColor {
        ThemeColor(role: .providerText(self))
    }

    /// A deeper shade of the hue for filled buttons, so white text on it stays readable in both appearances.
    var emphasisTintColor: Color {
        switch self {
        case .claude: .adaptive(light: 0xE0700F, dark: 0xD9691A)
        case .codex: .adaptive(light: 0x2F6BFF, dark: 0x3A6DF0)
        case .antigravity: .adaptive(light: 0x9A3FE6, dark: 0x9447E0)
        case .kiro: .adaptive(light: 0xC92F78, dark: 0xC4386F)
        case .opencode: .adaptive(light: 0x0E8072, dark: 0x14857A)
        case .pi: .adaptive(light: 0x2F8424, dark: 0x358A2A)
        }
    }
}
