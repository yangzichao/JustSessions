import Combine
import Foundation

@MainActor
final class AppThemeStore: ObservableObject {
    static let shared = AppThemeStore()

    @Published private(set) var resolvedTheme: ResolvedAppTheme
    @Published private(set) var terminalTheme: ResolvedAppTheme
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

    func resolvedTheme(for theme: AppTheme) -> ResolvedAppTheme {
        customizedThemes[theme] ?? ResolvedAppTheme(theme)
    }

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
