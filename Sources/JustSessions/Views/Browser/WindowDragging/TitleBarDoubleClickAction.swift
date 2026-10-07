import AppKit

/// What double-clicking a window's title bar does, as chosen in System Settings under Desktop & Dock.
enum TitleBarDoubleClickAction: Equatable {
    case zoom
    case minimize
    case nothing

    /// `AppleActionOnDoubleClick` holds the choice, and before it `AppleMiniaturizeOnDoubleClick` did; with neither
    /// set, a double-click zooms. Fill, offered since macOS 15, has no public counterpart for an app, so it zooms.
    init(actionSetting: String?, minimizesSetting: Bool) {
        switch actionSetting?.lowercased() {
        case "minimize": self = .minimize
        case "none": self = .nothing
        case "maximize", "fill": self = .zoom
        default: self = minimizesSetting ? .minimize : .zoom
        }
    }

    static var chosenInSystemSettings: Self {
        let settings = UserDefaults.standard
        return Self(
            actionSetting: settings.string(forKey: "AppleActionOnDoubleClick"),
            minimizesSetting: settings.bool(forKey: "AppleMiniaturizeOnDoubleClick")
        )
    }

    @MainActor
    func perform(on window: NSWindow) {
        switch self {
        case .zoom: window.zoom(nil)
        case .minimize: window.miniaturize(nil)
        case .nothing: break
        }
    }
}
