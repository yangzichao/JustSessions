import Foundation

struct FeedbackEnvironment: Equatable, Sendable {
    let appVersion: String
    let macOSVersion: String

    static var current: FeedbackEnvironment {
        let info = Bundle.main.infoDictionary ?? [:]
        let appVersion = appVersion(
            shortVersion: info["CFBundleShortVersionString"] as? String,
            buildNumber: info["CFBundleVersion"] as? String
        )
        let operatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        let macOSVersion = [operatingSystemVersion.majorVersion, operatingSystemVersion.minorVersion, operatingSystemVersion.patchVersion]
            .map(String.init)
            .joined(separator: ".")
        return FeedbackEnvironment(appVersion: appVersion, macOSVersion: macOSVersion)
    }

    static func appVersion(shortVersion: String?, buildNumber: String?) -> String {
        let shortVersion = shortVersion.flatMap { $0.isEmpty ? nil : $0 }
        let buildNumber = buildNumber.flatMap { $0.isEmpty ? nil : $0 }
        return switch (shortVersion, buildNumber) {
        case (let shortVersion?, let buildNumber?) where buildNumber != shortVersion: "\(shortVersion) (\(buildNumber))"
        case (let shortVersion?, _): shortVersion
        case (nil, _): "development build"
        }
    }

    var summary: String {
        "JustSessions \(appVersion) · macOS \(macOSVersion)"
    }
}
