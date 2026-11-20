import Foundation

enum SessionSummaryCacheLocation {
    static func file(named name: String, summaryLayoutVersion: Int) -> URL {
        let layoutVersionSuffix = summaryLayoutVersion == 1 ? "" : "-\(summaryLayoutVersion)"
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("SessionSummaries", isDirectory: true)
            .appendingPathComponent(name + layoutVersionSuffix + ".json")
    }
}
