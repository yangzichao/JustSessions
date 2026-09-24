import AppKit
import Foundation

struct AppUpdateNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let canInstall: Bool
}

@MainActor
final class AppUpdateManager: ObservableObject {
    @Published private(set) var isCheckingForUpdates = false
    @Published var notice: AppUpdateNotice?

    private let resultFile: URL = {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("claudex-macos/update-result.txt")
    }()

    private let logFile: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return logs.appendingPathComponent("Logs/claudex-macos/update.log")
    }()

    func checkForUpdates() {
        guard !isCheckingForUpdates else { return }
        isCheckingForUpdates = true
        Task {
            do {
                let configuration = try GitHubUpdateConfiguration.current()
                let check = try await Task.detached(priority: .userInitiated) {
                    try GitHubUpdateChecker.check(configuration)
                }.value
                if check.isUpdateAvailable {
                    notice = AppUpdateNotice(
                        title: "Update available",
                        message: "A newer version is on GitHub. Update now to download, build, and reopen claudex-macos?",
                        canInstall: true
                    )
                } else {
                    notice = AppUpdateNotice(
                        title: "Up to date",
                        message: "This app matches the latest main branch on GitHub.",
                        canInstall: false
                    )
                }
            } catch {
                notice = AppUpdateNotice(
                    title: "Could not check for updates",
                    message: error.localizedDescription,
                    canInstall: false
                )
            }
            isCheckingForUpdates = false
        }
    }

    func installUpdate(hasOpenTerminals: Bool) {
        guard !hasOpenTerminals else {
            notice = AppUpdateNotice(
                title: "Close open terminals first",
                message: "Close the running terminal tabs in claudex-macos, then select Update again. Updating restarts the app.",
                canInstall: false
            )
            return
        }

        do {
            let configuration = try GitHubUpdateConfiguration.current()
            let applicationBundle = Bundle.main.bundleURL
            let parentDirectory = applicationBundle.deletingLastPathComponent()
            guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
                throw AppUpdateError("The app folder is not writable: \(parentDirectory.path)")
            }
            let helper = configuration.sourceDirectory.appendingPathComponent("Scripts/update-app.sh")
            guard FileManager.default.isExecutableFile(atPath: helper.path) else {
                throw AppUpdateError("The update helper is missing or not executable: \(helper.path)")
            }

            let process = Process()
            process.executableURL = helper
            process.arguments = [
                configuration.sourceDirectory.path,
                applicationBundle.path,
                String(ProcessInfo.processInfo.processIdentifier),
                GitHubUpdateConfiguration.repositoryURL,
                resultFile.path,
                logFile.path
            ]
            try process.run()
            NSApplication.shared.terminate(nil)
        } catch {
            notice = AppUpdateNotice(
                title: "Could not start update",
                message: error.localizedDescription,
                canInstall: false
            )
        }
    }

    func showPendingResult() {
        guard let result = try? String(contentsOf: resultFile, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: resultFile)
        let lines = result.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let succeeded = lines.first == "success"
        notice = AppUpdateNotice(
            title: succeeded ? "Update complete" : "Update failed",
            message: lines.count > 1 ? String(lines[1]) : (succeeded ? "claudex-macos is up to date." : "See \(logFile.path)"),
            canInstall: false
        )
    }
}
