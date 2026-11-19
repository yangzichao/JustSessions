import Combine
import Foundation

@MainActor
final class TabCloseChoiceSettingsStore: ObservableObject {
    static let shared = TabCloseChoiceSettingsStore()

    @Published private(set) var choices: TabCloseChoicesByHost
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        choices = TabCloseChoicesByHost.load(from: userDefaults)
    }

    func choice(for host: SessionHost) -> TabCloseChoice {
        choices.choice(for: host)
    }

    func setChoice(_ newChoice: TabCloseChoice, for host: SessionHost) {
        guard newChoice != choices.choice(for: host) else { return }
        var newChoices = choices
        newChoices.setChoice(newChoice, for: host)
        newChoices.save(to: userDefaults)
        choices = newChoices
    }

    func forgetSSHHost(_ destination: String) {
        setChoice(.askEachTime, for: .ssh(destination))
    }
}
