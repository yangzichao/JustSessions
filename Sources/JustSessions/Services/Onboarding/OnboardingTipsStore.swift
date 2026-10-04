import Foundation

/// The onboarding tips shown so far. An install that was fresh when this was first read shows each tip once, those
/// added in later versions too. One that already had saved settings had been used, so it shows none; Help still
/// starts the tour.
@MainActor
final class OnboardingTipsStore {
    /// Created at launch, before anything else saves a setting, so a fresh install still looks like one.
    static let shared = OnboardingTipsStore(
        userDefaults: .standard,
        isFreshInstall: UserDefaults.standard.persistentDomain(forName: AppIdentity.currentBundleIdentifier)?.isEmpty ?? true
    )
    static let showsTipsKey = "showsOnboardingTips"
    static let shownTipsKey = "onboardingTipsShown"

    private let showsTips: Bool
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

    func markShown(_ tip: OnboardingTip) {
        guard shownTips.insert(tip).inserted else { return }
        userDefaults.set(OnboardingTip.allCases.filter(shownTips.contains).map(\.rawValue), forKey: Self.shownTipsKey)
    }
}
