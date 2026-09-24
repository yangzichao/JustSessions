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
    @Published private(set) var isInstallingUpdate = false
    @Published var notice: AppUpdateNotice?

    private var latestUpdate: GitHubUpdateCheck?
    private var hasCheckedAutomatically = false

    private let resultFile: URL = {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("JustSessions/update-result.txt")
    }()

    private let legacyResultFile: URL = {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent("coca-codex/update-result.txt")
    }()

    private let logFile: URL = {
        let logs = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return logs.appendingPathComponent("Logs/JustSessions/update.log")
    }()

    func checkForUpdates(automaticallyInstall: Bool = false, hasOpenTerminals: @escaping () -> Bool = { false }) {
        guard !isCheckingForUpdates && !isInstallingUpdate else { return }
        if automaticallyInstall {
            guard !hasCheckedAutomatically else { return }
            hasCheckedAutomatically = true
        }
        isCheckingForUpdates = true
        Task {
            do {
                guard let bundledRevision = Bundle.main.object(forInfoDictionaryKey: "JustSessionsSourceRevision") as? String else {
                    throw AppUpdateError("This app has no build revision. Rebuild it with Scripts/build-app.sh.")
                }
                let update = try await GitHubUpdateChecker.check(bundledRevision: bundledRevision)
                latestUpdate = update
                if update.isUpdateAvailable {
                    if automaticallyInstall && !hasOpenTerminals() {
                        isCheckingForUpdates = false
                        installUpdate(hasOpenTerminals: hasOpenTerminals)
                        return
                    }
                    notice = AppUpdateNotice(
                        title: "Update available",
                        message: "A newer version is ready on GitHub. Update now to download and reopen JustSessions?",
                        canInstall: true
                    )
                } else if !automaticallyInstall {
                    notice = AppUpdateNotice(
                        title: "Up to date",
                        message: "This app matches the latest published build on GitHub.",
                        canInstall: false
                    )
                }
            } catch {
                if !automaticallyInstall {
                    notice = AppUpdateNotice(
                        title: "Could not check for updates",
                        message: error.localizedDescription,
                        canInstall: false
                    )
                }
            }
            isCheckingForUpdates = false
        }
    }

    func installUpdate(hasOpenTerminals: @escaping () -> Bool) {
        guard !hasOpenTerminals() else {
            notice = AppUpdateNotice(
                title: "Close open terminals first",
                message: "Close the running terminal tabs, then select Update again. Updating restarts the app.",
                canInstall: false
            )
            return
        }
        guard let update = latestUpdate, update.isUpdateAvailable else { return }
        let applicationBundle = Bundle.main.bundleURL
        let parentDirectory = applicationBundle.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
            notice = AppUpdateNotice(
                title: "Could not update",
                message: "The app folder is not writable: \(parentDirectory.path)",
                canInstall: false
            )
            return
        }
        guard let helper = Bundle.main.resourceURL?.appendingPathComponent("update-app.sh"),
              FileManager.default.isExecutableFile(atPath: helper.path) else {
            notice = AppUpdateNotice(
                title: "Could not update",
                message: "The installed app has no update helper.",
                canInstall: false
            )
            return
        }

        isInstallingUpdate = true
        Task {
            do {
                let download = try await UpdateArchiveDownloader.download(update)
                guard !hasOpenTerminals() else {
                    try? FileManager.default.removeItem(at: download.directory)
                    throw AppUpdateError("A terminal was opened while downloading. Close it and try Update again.")
                }
                let process = Process()
                process.executableURL = helper
                process.arguments = [
                    download.archive.path,
                    applicationBundle.path,
                    String(ProcessInfo.processInfo.processIdentifier),
                    update.latestRevision,
                    update.archiveSHA256,
                    resultFile.path,
                    logFile.path,
                    download.directory.path
                ]
                do {
                    try process.run()
                } catch {
                    try? FileManager.default.removeItem(at: download.directory)
                    throw error
                }
                NSApplication.shared.terminate(nil)
            } catch {
                notice = AppUpdateNotice(
                    title: "Could not update",
                    message: error.localizedDescription,
                    canInstall: false
                )
                isInstallingUpdate = false
            }
        }
    }

    @discardableResult
    func showPendingResult() -> Bool {
        let pendingFile = FileManager.default.fileExists(atPath: resultFile.path) ? resultFile : legacyResultFile
        guard let result = try? String(contentsOf: pendingFile, encoding: .utf8) else { return false }
        try? FileManager.default.removeItem(at: pendingFile)
        let lines = result.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let succeeded = lines.first == "success"
        notice = AppUpdateNotice(
            title: succeeded ? "Update complete" : "Update failed",
            message: lines.count > 1 ? String(lines[1]) : (succeeded ? "JustSessions is up to date." : "See \(logFile.path)"),
            canInstall: false
        )
        return true
    }
}
