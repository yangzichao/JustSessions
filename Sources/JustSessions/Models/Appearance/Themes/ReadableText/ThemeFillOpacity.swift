/// How strongly the app's faint fills cover a surface. Text is checked for contrast on these fills too, so views and
/// `AppThemeColors.textSurfaces` share them.
enum ThemeFillOpacity {
    /// The theme's line color under the pointer.
    static let hover = 0.055
    /// The theme's line color behind a segmented control or a table's header row.
    static let track = 0.06
    /// The theme's line color on a held-down control.
    static let pressed = 0.14
    /// The theme's line color in hairlines between regions and around raised controls.
    static let hairline = 0.09
    /// A selected sidebar row's CLI hue, or the ink for a row without a CLI.
    static let selectedRow = 0.13
}
