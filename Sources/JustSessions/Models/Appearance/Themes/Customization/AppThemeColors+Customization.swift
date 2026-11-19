extension AppThemeColors {
    func applying(_ changedColors: [CustomizableThemeColor: UInt32]) -> AppThemeColors {
        changedColors.isEmpty ? self : AppThemeColors(seeds: seeds.applying(changedColors))
    }
}
