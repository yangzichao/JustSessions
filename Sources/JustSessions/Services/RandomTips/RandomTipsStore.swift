import Combine
import Foundation

@MainActor
final class RandomTipsStore: ObservableObject {
    static let shared = RandomTipsStore(
        userDefaults: .standard,
        waitsForNextLaunch: OnboardingTipsStore.shared.shouldShow(.tour)
    )
    static let showsTipsKey = "showsRandomTips"
    static let shownTipsKey = "randomTipsShown"

    @Published private(set) var showsTips: Bool
    @Published private(set) var currentTip: RandomTip?
    private var rotation: RandomTipRotation
    private let userDefaults: UserDefaults
    private let randomIndex: (Int) -> Int

    init(
        userDefaults: UserDefaults,
        waitsForNextLaunch: Bool,
        randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }
    ) {
        self.userDefaults = userDefaults
        self.randomIndex = randomIndex
        showsTips = userDefaults.object(forKey: Self.showsTipsKey) as? Bool ?? true
        let savedShownTips = (userDefaults.stringArray(forKey: Self.shownTipsKey) ?? []).compactMap(RandomTip.init(rawValue:))
        rotation = RandomTipRotation(shownTips: Set(savedShownTips))
        if !waitsForNextLaunch {
            showNextTip()
        }
    }

    func showNextTip() {
        guard showsTips else { return }
        currentTip = rotation.nextTip(after: currentTip, randomIndex: randomIndex)
        userDefaults.set(RandomTip.allCases.filter(rotation.shownTips.contains).map(\.rawValue), forKey: Self.shownTipsKey)
    }

    func hideUntilNextLaunch() {
        currentTip = nil
    }

    func setShowsTips(_ showsTips: Bool) {
        guard showsTips != self.showsTips else { return }
        self.showsTips = showsTips
        userDefaults.set(showsTips, forKey: Self.showsTipsKey)
        if showsTips {
            showNextTip()
        } else {
            currentTip = nil
        }
    }
}
