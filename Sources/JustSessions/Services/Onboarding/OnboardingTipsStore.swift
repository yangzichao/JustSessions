import Foundation

@MainActor
final class OnboardingTipsStore {
    static let shared = OnboardingTipsStore(
        userDefaults: .standard,
        isFreshInstall: UserDefaults.standard.persistentDomain(forName: AppIdentity.currentBundleIdentifier)?.isEmpty ?? true
    )
    static let showsTipsKey = "showsOnboardingTips"
    static let shownTipsKey = "onboardingTipsShown"

    private var showsTips: Bool
    private var shownTips: Set<OnboardingTip>
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults, isFreshInstall: @autoclosure () -> Bool) {
        self.userDefaults = userDefaults
        if userDefaults.object(forKey: Self.showsTipsKey) == nil {
            userDefaults.set(isFreshInstall(), forKey: Self.showsTipsKey)
        }
        showsTips = userDefaults.bool(forKey: Self.showsTipsKey)
        shownTips = Set((userDefaults.stringArray(forKey: Self.shownTipsKey) ?? []).compactMap(OnboardingTip.init(rawValue:)))
    }

    var tipsToShow: Set<OnboardingTip> {
        showsTips ? Set(OnboardingTip.allCases).subtracting(shownTips) : []
    }

    func shouldShow(_ tip: OnboardingTip) -> Bool {
        showsTips && !shownTips.contains(tip)
    }

    func showEveryTipAgain() {
        showsTips = true
        shownTips = []
        userDefaults.set(true, forKey: Self.showsTipsKey)
        userDefaults.removeObject(forKey: Self.shownTipsKey)
    }

    func markShown(_ tip: OnboardingTip) {
        guard shownTips.insert(tip).inserted else { return }
        userDefaults.set(OnboardingTip.allCases.filter(shownTips.contains).map(\.rawValue), forKey: Self.shownTipsKey)
    }
}
