import Foundation

struct LiveSessionReporting: Sendable {
    static let reportsDirectoryVariable = "JUSTSESSIONS_LIVE_SESSION_REPORTS"

    let directory: URL

    static var ofThePackagedApp: LiveSessionReporting? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return LiveSessionReporting(
            directory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(AppIdentity.currentBundleIdentifier)
                .appendingPathComponent("LiveSessionReporting", isDirectory: true))
    }

    var reportsDirectory: URL {
        directory.appendingPathComponent("reports", isDirectory: true)
    }

    func launchAdditions(for provider: ConversationProvider, environment: [String: String]) -> LiveSessionReporterLaunch? {
        let reportsVariable = [Self.reportsDirectoryVariable: reportsDirectory.path]
        switch provider {
        case .pi:
            let extensionFile = directory.appendingPathComponent("pi/\(PiLiveSessionExtension.fileName)")
            guard Self.write(PiLiveSessionExtension.source, to: extensionFile) else { return nil }
            return LiveSessionReporterLaunch(arguments: ["--extension", extensionFile.path], environment: reportsVariable)
        case .opencode:
            guard environment[OpenCodeLiveSessionPlugin.tuiConfigurationVariable] == nil else { return nil }
            let pluginFile = directory.appendingPathComponent("opencode/\(OpenCodeLiveSessionPlugin.fileName)")
            let tuiConfigurationFile = directory.appendingPathComponent("opencode/tui.json")
            guard Self.write(OpenCodeLiveSessionPlugin.source, to: pluginFile),
                let tuiConfiguration = OpenCodeLiveSessionPlugin.tuiConfiguration(loading: pluginFile),
                Self.write(tuiConfiguration, to: tuiConfigurationFile)
            else { return nil }
            return LiveSessionReporterLaunch(
                arguments: [],
                environment: reportsVariable.merging([OpenCodeLiveSessionPlugin.tuiConfigurationVariable: tuiConfigurationFile.path]) { $1 }
            )
        case .claude, .codex, .antigravity, .kiro:
            return nil
        }
    }

    func report(forProcessID processID: Int32) -> LiveSessionReport? {
        guard processID > 0,
            let data = try? Data(contentsOf: reportsDirectory.appendingPathComponent("\(processID).json"))
        else { return nil }
        return LiveSessionReport(jsonData: data, processID: processID)
    }

    func removeReportsOfExitedProcessesInBackground() {
        let reportsDirectory = self.reportsDirectory
        Task.detached(priority: .background) {
            let fileNames = (try? FileManager.default.contentsOfDirectory(atPath: reportsDirectory.path)) ?? []
            for fileName in fileNames {
                guard let processID = Int32(fileName.replacingOccurrences(of: ".json", with: "")),
                    !RunningProcessInfo.isRunning(processID)
                else { continue }
                try? FileManager.default.removeItem(at: reportsDirectory.appendingPathComponent(fileName))
            }
        }
    }

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
