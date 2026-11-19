import Combine
import Foundation

/// The saved choice of what the Option key does in a terminal, with either engine. On, as it is until you turn it off,
/// Option is Meta: Option with a key sends Esc and that key, which shells and CLIs read as Alt shortcuts. Off, Option
/// with a key types what the keyboard layout gives it, which a layout that keeps brackets, braces, the pipe, or the
/// tilde behind Option needs. Open terminals follow a change.
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
