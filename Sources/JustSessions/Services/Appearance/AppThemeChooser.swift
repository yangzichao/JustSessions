/// What choosing a theme in Settings does: the app takes the theme, and terminals take its colors too, replacing a
/// color scheme chosen for them before. The terminal Colors menu can still pick another one afterward, and imported
/// colors stay in it.
@MainActor
struct AppThemeChooser {
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

    func choose(_ theme: AppTheme) {
        appThemeStore.setTheme(theme)
        terminalAppearanceStore.setColorChoice(.matchAppTheme)
    }
}
