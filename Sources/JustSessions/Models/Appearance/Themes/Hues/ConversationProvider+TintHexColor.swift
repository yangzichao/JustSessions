extension ConversationProvider {
    /// The CLI's hue, from the brand palette (Branding/README.md) for the first three, a little lighter in dark mode so it
    /// keeps its contrast.
    var tintHexColor: AdaptiveHexColor {
        switch self {
        case .claude: AdaptiveHexColor(light: 0xFF8A1F, dark: 0xFF9C45)
        case .codex: AdaptiveHexColor(light: 0x2F6BFF, dark: 0x5C8CFF)
        case .antigravity: AdaptiveHexColor(light: 0xA64DF0, dark: 0xBA78F5)
        case .kiro: AdaptiveHexColor(light: 0xE0408A, dark: 0xF0679F)
        case .opencode: AdaptiveHexColor(light: 0x12A08F, dark: 0x3CC4B2)
        case .pi: AdaptiveHexColor(light: 0x3F9F2F, dark: 0x6CC25A)
        }
    }
}
