/// The hues that carry the same meaning in every theme. Status glyphs show them as they are. Text in them is first made
/// readable on the theme's surfaces (see `AppThemeColors.warningText`).
enum StatusHexColors {
    /// A running CLI.
    static let live = AdaptiveHexColor(light: 0x1FA463, dark: 0x3DD68C)
    /// Something that needs your attention, such as a CLI waiting on your answer or an unreachable remote host.
    static let warning = AdaptiveHexColor(light: 0xE0892B, dark: 0xF2A54A)
    /// A turn a CLI finished that you have not looked at yet, blue as Mail, Claude, and Codex mark what is unread.
    static let unseenTurn = AdaptiveHexColor(light: 0x2A78D6, dark: 0x4C93EA)
    /// An error, in the system red.
    static let error = AdaptiveHexColor(light: 0xFF3B30, dark: 0xFF453A)
}
