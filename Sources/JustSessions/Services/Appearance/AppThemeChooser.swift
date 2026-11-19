@MainActor
struct AppThemeChooser {
    let appThemeStore: AppThemeStore
    let terminalAppearanceStore: TerminalAppearanceStore

    func choose(_ theme: AppTheme) {
        appThemeStore.setTheme(theme)
        terminalAppearanceStore.setColorChoice(.matchAppTheme)
    }
}
