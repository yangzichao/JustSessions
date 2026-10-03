import Foundation

enum SessionSummaryCacheLocation {
    static func file(named name: String) -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("SessionSummaries", isDirectory: true)
            .appendingPathComponent(name + ".json")
    }
}
