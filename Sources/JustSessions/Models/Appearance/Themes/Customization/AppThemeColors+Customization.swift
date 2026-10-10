extension AppThemeColors {
    /// The variant with the changed colors in place of its own; itself when nothing changed, so a built-in theme does
    /// no contrast work again.
    func applying(_ changedColors: [CustomizableThemeColor: UInt32]) -> AppThemeColors {
        changedColors.isEmpty ? self : AppThemeColors(seeds: seeds.applying(changedColors))
    }
}
