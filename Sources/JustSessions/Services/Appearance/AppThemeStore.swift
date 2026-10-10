import Combine
import Foundation

/// The theme chosen in Settings, and your changes to each theme's colors. Each window puts the chosen theme in its
/// views' environment, and terminals restyle from it.
@MainActor
final class AppThemeStore: ObservableObject {
    static let shared = AppThemeStore()

    /// The chosen theme with your changes to its colors.
    @Published private(set) var resolvedTheme: ResolvedAppTheme
    /// The chosen theme as terminals and the tab bar take it. It follows `resolvedTheme` at once, except while colors
    /// are picked: then it waits until picking pauses, so a drag across the color panel restyles terminals, and tells
    /// the CLIs that subscribe to theme changes, once rather than at every step.
    @Published private(set) var terminalTheme: ResolvedAppTheme
    /// The themes with your changes, kept when you choose another theme so they come back with it.
    private var customizedThemes: [AppTheme: ResolvedAppTheme]
    private let userDefaults: UserDefaults
    private let terminalThemeDelay: Duration
    private var pendingTerminalTheme: Task<Void, Never>?

    var theme: AppTheme { resolvedTheme.theme }

    init(userDefaults: UserDefaults = .standard, terminalThemeDelay: Duration = .milliseconds(250)) {
        self.userDefaults = userDefaults
        self.terminalThemeDelay = terminalThemeDelay
        let customizedThemes = AppThemeCustomization.loadAll(from: userDefaults).reduce(into: [AppTheme: ResolvedAppTheme]()) {
            customizedThemes, saved in customizedThemes[saved.key] = ResolvedAppTheme(saved.key, customization: saved.value)
        }
        let theme = AppTheme.load(from: userDefaults)
        let resolvedTheme = customizedThemes[theme] ?? ResolvedAppTheme(theme)
        self.customizedThemes = customizedThemes
        self.resolvedTheme = resolvedTheme
        terminalTheme = resolvedTheme
    }

    func setTheme(_ newTheme: AppTheme) {
        guard newTheme != theme else { return }
        newTheme.save(to: userDefaults)
        publish(resolvedTheme(for: newTheme), terminalsWait: false)
    }

    /// Any theme with your changes, as the theme picker draws it.
    func resolvedTheme(for theme: AppTheme) -> ResolvedAppTheme {
        customizedThemes[theme] ?? ResolvedAppTheme(theme)
    }

    /// Changes one color of the chosen theme's light or dark version; nil, or the theme's own color, gives it back the
    /// theme's own. Returns false, changing nothing, when a surface would not suit the version: of the wrong lightness,
    /// or too close to it for text to stay readable. Any text color, and going back to the theme's own, is taken.
    @discardableResult
    func setColor(_ value: UInt32?, for color: CustomizableThemeColor, isDark: Bool) -> Bool {
        let themeColors = theme.colors(isDark: isDark)
        let isThemesOwn = value.map { $0 == color.value(in: themeColors.seeds) || $0 == color.drawnValue(in: themeColors) } ?? true
        var customization = resolvedTheme.customization
        customization.setChange(isThemesOwn ? nil : value, for: color, isDark: isDark)
        guard themeColors.seeds.applying(customization.changes(isDark: isDark)).surfacesSuit(isDark: isDark) else { return false }
        guard customization != resolvedTheme.customization else { return true }
        save(resolvedTheme.replacingCustomization(with: customization, changedVersionIsDark: isDark), terminalsWait: true)
        return true
    }

    /// Gives the chosen theme back all its own colors.
    func removeCustomization() {
        guard !resolvedTheme.customization.isEmpty else { return }
        save(ResolvedAppTheme(theme), terminalsWait: false)
    }

    private func save(_ newResolvedTheme: ResolvedAppTheme, terminalsWait: Bool) {
        customizedThemes[theme] = newResolvedTheme.customization.isEmpty ? nil : newResolvedTheme
        AppThemeCustomization.saveAll(customizedThemes.mapValues(\.customization), to: userDefaults)
        publish(newResolvedTheme, terminalsWait: terminalsWait)
    }

    private func publish(_ newResolvedTheme: ResolvedAppTheme, terminalsWait: Bool) {
        resolvedTheme = newResolvedTheme
        pendingTerminalTheme?.cancel()
        guard terminalsWait else {
            terminalTheme = newResolvedTheme
            return
        }
        pendingTerminalTheme = Task { [weak self, terminalThemeDelay] in
            try? await Task.sleep(for: terminalThemeDelay)
            guard !Task.isCancelled, let self else { return }
            terminalTheme = resolvedTheme
        }
    }
}
