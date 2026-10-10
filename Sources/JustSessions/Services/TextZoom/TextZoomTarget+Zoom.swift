import Foundation

extension TextZoomTarget {
    @MainActor
    func zoom(
        _ step: TextZoomStep,
        terminalAppearanceStore: TerminalAppearanceStore = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        switch self {
        case .terminals: terminalAppearanceStore.zoomFont(step)
        case .conversation: TranscriptReadingTextSize.zoom(step, in: userDefaults)
        }
    }
}
