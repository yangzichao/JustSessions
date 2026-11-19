enum CustomizableThemeColor: String, CaseIterable, Identifiable, Sendable {
    case contentSurface
    case sidebarSurface
    case raisedSurface
    case userMessageSurface
    case ink

    var id: String { rawValue }

    func value(in seeds: AppThemeSeeds) -> UInt32 {
        switch self {
        case .contentSurface: seeds.contentSurface
        case .sidebarSurface: seeds.sidebarSurface
        case .raisedSurface: seeds.raisedSurface
        case .userMessageSurface: seeds.userMessageSurface
        case .ink: seeds.ink
        }
    }

    func drawnValue(in colors: AppThemeColors) -> UInt32 {
        self == .ink ? colors.ink : value(in: colors.seeds)
    }
}
