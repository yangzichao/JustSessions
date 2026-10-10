/// The colors of a theme you can change in Settings. The rest follow from them: supporting text is faded from the
/// text color, every text color is made readable on the surfaces, and hover fills and hairlines take the text color.
/// Terminals that match the app theme sit on its background.
enum CustomizableThemeColor: String, CaseIterable, Identifiable, Sendable {
    case contentSurface
    case sidebarSurface
    case raisedSurface
    case userMessageSurface
    /// The theme's ink: text, and where other apps put the system accent.
    case ink

    var id: String { rawValue }

    var isSurface: Bool { self != .ink }

    /// The color the variant was made from.
    func value(in seeds: AppThemeSeeds) -> UInt32 {
        switch self {
        case .contentSurface: seeds.contentSurface
        case .sidebarSurface: seeds.sidebarSurface
        case .raisedSurface: seeds.raisedSurface
        case .userMessageSurface: seeds.userMessageSurface
        case .ink: seeds.ink
        }
    }

    /// The color as the app draws it: a surface as it is, the ink once made readable.
    func drawnValue(in colors: AppThemeColors) -> UInt32 {
        self == .ink ? colors.ink : value(in: colors.seeds)
    }
}
