import Combine
import Foundation

@MainActor
final class TerminalOptionKeyStore: ObservableObject {
    static let shared = TerminalOptionKeyStore()
    static let userDefaultsKey = "terminalOptionIsMeta"
    static let defaultOptionIsMeta = true

    @Published private(set) var optionIsMeta: Bool
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        optionIsMeta = userDefaults.object(forKey: Self.userDefaultsKey) as? Bool ?? Self.defaultOptionIsMeta
    }

    func setOptionIsMeta(_ optionIsMeta: Bool) {
        guard optionIsMeta != self.optionIsMeta else { return }
        userDefaults.set(optionIsMeta, forKey: Self.userDefaultsKey)
        self.optionIsMeta = optionIsMeta
    }
}
