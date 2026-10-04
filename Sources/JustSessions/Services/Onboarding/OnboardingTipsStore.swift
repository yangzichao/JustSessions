import Foundation

/// The onboarding tips still to show on their own. A fresh install shows each once. An install that already had saved
/// settings when this was first read has been used, so it shows none; Help still starts the tour.
@MainActor
final class OnboardingTipsStore {
    /// Created at launch, before anything else saves a setting, so a fresh install still looks like one.
    static let shared = OnboardingTipsStore(
        userDefaults: .standard,
        isFreshInstall: UserDefaults.standard.persistentDomain(forName: AppIdentity.currentBundleIdentifier)?.isEmpty ?? true
    )
    static let userDefaultsKey = "onboardingTipsToShow"

    private(set) var tipsToShow: Set<OnboardingTip>
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults, isFreshInstall: @autoclosure () -> Bool) {
        self.userDefaults = userDefaults
        if let savedTips = userDefaults.stringArray(forKey: Self.userDefaultsKey) {
            tipsToShow = Set(savedTips.compactMap(OnboardingTip.init(rawValue:)))
        } else {
            tipsToShow = isFreshInstall() ? Set(OnboardingTip.allCases) : []
            save()
        }
    }

    func shouldShow(_ tip: OnboardingTip) -> Bool {
        tipsToShow.contains(tip)
    }

    func markShown(_ tip: OnboardingTip) {
        guard tipsToShow.remove(tip) != nil else { return }
        save()
    }

    private func save() {
        userDefaults.set(OnboardingTip.allCases.filter(tipsToShow.contains).map(\.rawValue), forKey: Self.userDefaultsKey)
    }
}
