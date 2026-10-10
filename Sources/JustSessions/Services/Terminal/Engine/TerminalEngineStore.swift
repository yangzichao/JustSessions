import Combine
import Foundation

/// The saved choice of terminal engine for tabs opened from now on; see `TerminalEngine`. Tabs open with SwiftTerm
/// until Ghostty is chosen. Kept apart from the terminal appearance, so restoring its defaults leaves the engine alone.
@MainActor
final class TerminalEngineStore: ObservableObject {
    static let shared = TerminalEngineStore()
    static let userDefaultsKey = "terminalEngine"
    static let defaultEngine = TerminalEngine.swiftTerm

    @Published private(set) var engine: TerminalEngine
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        engine = userDefaults.string(forKey: Self.userDefaultsKey).flatMap(TerminalEngine.init(rawValue:)) ?? Self.defaultEngine
    }

    func setEngine(_ engine: TerminalEngine) {
        guard engine != self.engine else { return }
        userDefaults.set(engine.rawValue, forKey: Self.userDefaultsKey)
        self.engine = engine
    }
}
