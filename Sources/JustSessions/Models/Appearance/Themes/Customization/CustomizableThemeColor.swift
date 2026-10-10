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

    func value(in seeds: AppThemeSeeds) -> UInt32 {
        switch self {
        case .contentSurface: seeds.contentSurface
        case .sidebarSurface: seeds.sidebarSurface
        case .raisedSurface: seeds.raisedSurface
        case .userMessageSurface: seeds.userMessageSurface
        case .ink: seeds.ink
        }
    }
}

extension AppThemeSeeds {
    /// These seeds with the changed colors in place of their own. Hairlines and hover fills follow a changed ink, as
    /// they do in nearly every built-in theme.
    func applying(_ changedColors: [CustomizableThemeColor: UInt32]) -> AppThemeSeeds {
        var seeds = self
        for (color, value) in changedColors {
            switch color {
            case .contentSurface: seeds.contentSurface = value
            case .sidebarSurface: seeds.sidebarSurface = value
            case .raisedSurface: seeds.raisedSurface = value
            case .userMessageSurface: seeds.userMessageSurface = value
            case .ink:
                seeds.ink = value
                seeds.line = value
            }
        }
        return seeds
    }
}
