import Foundation

enum AppIdentity {
    static let bundleIdentifier = "dev.zichaoyang.justsessions"

    static var currentBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? bundleIdentifier
    }
}
