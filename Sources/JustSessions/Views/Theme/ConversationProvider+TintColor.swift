import SwiftUI

extension ConversationProvider {
    /// The CLI's hue, from the brand palette (Branding/README.md) for the first three, a little lighter in dark mode so it
    /// keeps its contrast.
    var tintColor: Color {
        switch self {
        case .claude: .adaptive(light: 0xFF8A1F, dark: 0xFF9C45)
        case .codex: .adaptive(light: 0x2F6BFF, dark: 0x5C8CFF)
        case .antigravity: .adaptive(light: 0xA64DF0, dark: 0xBA78F5)
        case .kiro: .adaptive(light: 0xE0408A, dark: 0xF0679F)
        case .opencode: .adaptive(light: 0x12A08F, dark: 0x3CC4B2)
        case .pi: .adaptive(light: 0x3F9F2F, dark: 0x6CC25A)
        }
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
