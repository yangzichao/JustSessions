import Foundation

/// What the About window says about this copy of the app: its version, and the copyright and license in LICENSE.
enum AboutAppDetails {
    static let copyrightYear = 2026
    static let copyrightHolder = "Zichao Yang"

    /// Such as "© 2026 Zichao Yang". Names and years read the same in every language.
    static var copyrightNotice: String {
        "© \(copyrightYear) \(copyrightHolder)"
    }

    /// The running bundle's version, such as "1.2.0 (120)".
    static var currentVersion: String? {
        let info = Bundle.main.infoDictionary ?? [:]
        return version(
            shortVersion: info["CFBundleShortVersionString"] as? String,
            buildNumber: info["CFBundleVersion"] as? String
        )
    }

    /// Nil without a version, as under `swift run`, so the window can say it is a development build.
    static func version(shortVersion: String?, buildNumber: String?) -> String? {
        guard let shortVersion, !shortVersion.isEmpty else { return nil }
        return FeedbackEnvironment.appVersion(shortVersion: shortVersion, buildNumber: buildNumber)
    }
}
