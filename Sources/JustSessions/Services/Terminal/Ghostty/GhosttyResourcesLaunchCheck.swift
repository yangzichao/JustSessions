import Darwin
import Foundation
import GhosttyTerminal

@MainActor
enum GhosttyResourcesLaunchCheck {
    static let userDefaultsKey = "checksGhosttyResourcesAtLaunch"

    static func runIfAsked(userDefaults: UserDefaults = .standard) {
        guard userDefaults.bool(forKey: userDefaultsKey) else { return }
        _ = GhosttyTerminalControllers.shared.controller(appearanceStore: .shared, themeStore: .shared)
        guard GhosttyRuntimeResources.directoryURL != nil, GhosttyRuntimeResources.terminfoDirectoryURL != nil else {
            FileHandle.standardError.write(Data("Ghostty's shell integration or terminfo is missing from the app.\n".utf8))
            exit(1)
        }
    }
}
