import Foundation

/// The versions a feedback report starts with, so a problem can be matched to the app and macOS it happened on.
struct FeedbackEnvironment: Equatable, Sendable {
    let appVersion: String
    let macOSVersion: String

    static var current: FeedbackEnvironment {
        let info = Bundle.main.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String
        let buildNumber = info["CFBundleVersion"] as? String
        let appVersion = switch (shortVersion, buildNumber) {
        case let (shortVersion?, buildNumber?) where buildNumber != shortVersion: "\(shortVersion) (\(buildNumber))"
        case let (shortVersion?, _): shortVersion
        case (nil, _): "development build"
        }
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = [operatingSystemVersion.majorVersion, operatingSystemVersion.minorVersion, operatingSystemVersion.patchVersion]
            .map(String.init)
            .joined(separator: ".")
        return FeedbackEnvironment(appVersion: appVersion, macOSVersion: macOSVersion)
    }

    /// Such as "JustSessions 0.45.0 (45) · macOS 26.0.1". Product names and versions read the same in every language.
    var summary: String {
        "JustSessions \(appVersion) · macOS \(macOSVersion)"
    }
}
