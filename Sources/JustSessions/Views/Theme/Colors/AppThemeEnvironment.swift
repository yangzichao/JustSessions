import SwiftUI

extension EnvironmentValues {
    @Entry var appTheme = ResolvedAppTheme(.justSessions)
}

extension View {
    func appTheme(from themeStore: AppThemeStore) -> some View {
        modifier(ChosenAppTheme(themeStore: themeStore))
    }
}

private struct ChosenAppTheme: ViewModifier {
    @ObservedObject var themeStore: AppThemeStore

    func body(content: Content) -> some View {
        content
            .tint(ThemePalette.ink)
            .environment(\.appTheme, themeStore.resolvedTheme)
            .font(ThemeFont.body)
            .controlSize(InterfaceScale.controlSize)
    }
}
