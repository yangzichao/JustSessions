/// The colors one theme variant is made from, as 0xRRGGBB values. `AppThemeColors` makes its text colors readable on
/// them and works out the rest.
struct AppThemeSeeds: Equatable, Sendable {
    var sidebarSurface: UInt32
    var contentSurface: UInt32
    var raisedSurface: UInt32
    var userMessageSurface: UInt32
    var ink: UInt32
    var inkForeground: UInt32
    var line: UInt32
    var terminal: TerminalColorScheme
}
