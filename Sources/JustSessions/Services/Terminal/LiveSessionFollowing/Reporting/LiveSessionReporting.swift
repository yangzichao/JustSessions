import Foundation

/// Pi and OpenCode say which session they are in, and what they are doing, only to code that runs inside them. The
/// app starts them on this Mac with a small extension of its own, which writes both to `reports/<pid>.json` whenever
/// they change; see `PiLiveSessionExtension` and `OpenCodeLiveSessionPlugin`. The app keeps the extensions in
/// `directory` and rewrites them when they change.
struct LiveSessionReporting: Sendable {
    static let reportsDirectoryVariable = "JUSTSESSIONS_LIVE_SESSION_REPORTS"

    let directory: URL

    /// Only the packaged app reports, so tests and `swift run` leave the app's own folder alone.
    static var thisApp: LiveSessionReporting? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return LiveSessionReporting(directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.currentBundleIdentifier)
            .appendingPathComponent("LiveSessionReporting", isDirectory: true))
    }

    var reportsDirectory: URL {
        directory.appendingPathComponent("reports", isDirectory: true)
    }

    /// What the tool's CLI is started with so it reports its session; nil for a tool that cannot, or when the
    /// extension could not be written. `environment` is what the CLI runs with otherwise.
    func launchAdditions(for provider: ConversationProvider, environment: [String: String]) -> LiveSessionReporterLaunch? {
        let reportsVariable = [Self.reportsDirectoryVariable: reportsDirectory.path]
        switch provider {
        case .pi:
            let extensionFile = directory.appendingPathComponent("pi/\(PiLiveSessionExtension.fileName)")
            guard Self.write(PiLiveSessionExtension.source, to: extensionFile) else { return nil }
            return LiveSessionReporterLaunch(arguments: ["--extension", extensionFile.path], environment: reportsVariable)
        case .opencode:
            // A TUI configuration of the user's own stays in place; that OpenCode does not report.
            guard environment[OpenCodeLiveSessionPlugin.tuiConfigurationVariable] == nil else { return nil }
            let pluginFile = directory.appendingPathComponent("opencode/\(OpenCodeLiveSessionPlugin.fileName)")
            let tuiConfigurationFile = directory.appendingPathComponent("opencode/tui.json")
            guard Self.write(OpenCodeLiveSessionPlugin.source, to: pluginFile),
                  let tuiConfiguration = OpenCodeLiveSessionPlugin.tuiConfiguration(loading: pluginFile),
                  Self.write(tuiConfiguration, to: tuiConfigurationFile) else { return nil }
            return LiveSessionReporterLaunch(
                arguments: [],
                environment: reportsVariable.merging([OpenCodeLiveSessionPlugin.tuiConfigurationVariable: tuiConfigurationFile.path]) { $1 }
            )
        case .claude, .codex, .antigravity, .kiro:
            return nil
        }
    }

    /// What the CLI with this process id last reported; nil when it reported nothing.
    func report(forProcessID processID: Int32) -> LiveSessionReport? {
        guard processID > 0,
              let data = try? Data(contentsOf: reportsDirectory.appendingPathComponent("\(processID).json")) else { return nil }
        return LiveSessionReport(jsonData: data, processID: processID)
    }

    /// A CLI removes its report when it quits, but not when it is killed.
    func removeReportsOfExitedProcessesInBackground() {
        let reportsDirectory = self.reportsDirectory
        Task.detached(priority: .background) {
            let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: reportsDirectory.path)) ?? []
            for fileName in fileNames {
                guard let processID = Int32(fileName.replacingOccurrences(of: ".json", with: "")),
                      !RunningProcessInfo.isRunning(processID) else { continue }
                try? FileManager.default.removeItem(at: reportsDirectory.appendingPathComponent(fileName))
            }
        }
    }

    /// Writes the file only when it differs, and atomically, so a CLI that loads it never reads half of it.
    private static func write(_ contents: String, to file: URL) -> Bool {
        let data = Data(contents.utf8)
        if (try? Data(contentsOf: file)) == data { return true }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
