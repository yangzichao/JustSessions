import Foundation

/// How macOS identifies the app. `Scripts/build-app.sh` writes the same identifier into the bundle's Info.plist.
enum AppIdentity {
    static let bundleIdentifier = "dev.zichaoyang.justsessions"

    /// The running bundle's identifier, or the app's own when running without its bundle, as under `swift run`.
    static var currentBundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? bundleIdentifier
    }
}
