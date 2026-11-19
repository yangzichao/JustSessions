import Foundation

struct FoundCrashReport: Equatable, Sendable {
    let file: URL
    let writtenAt: Date
    let summary: CrashReportSummary
}

struct CrashReportFinder: Sendable {
    let reportsDirectory: URL
    let executableName: String
    let bundleIdentifier: String

    static let maximumReportsRead = 10

    init(
        reportsDirectory: URL = CrashReportFinder.userReportsDirectory,
        executableName: String = Bundle.main.executableURL?.lastPathComponent ?? "JustSessions",
        bundleIdentifier: String = AppIdentity.currentBundleIdentifier
    ) {
        self.reportsDirectory = reportsDirectory
        self.executableName = executableName
        self.bundleIdentifier = bundleIdentifier
    }

    static var userReportsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    }

    func newestReport(writtenAfter date: Date) -> FoundCrashReport? {
        let files =
            (try? FileManager.default.contentsOfDirectory(
                at: reportsDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            )) ?? []
        let newFiles: [(file: URL, writtenAt: Date)] = files.compactMap { file in
            guard file.pathExtension == "ips", file.lastPathComponent.hasPrefix("\(executableName)-"),
                let writtenAt = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                writtenAt > date
            else { return nil }
            return (file, writtenAt)
        }
        for (file, writtenAt) in newFiles.sorted(by: { $0.writtenAt > $1.writtenAt }).prefix(Self.maximumReportsRead) {
            guard let text = try? String(contentsOf: file, encoding: .utf8),
                let summary = CrashReportSummary(reportText: text),
                summary.bundleIdentifier == bundleIdentifier
            else { continue }
            return FoundCrashReport(file: file, writtenAt: writtenAt, summary: summary)
        }
        return nil
    }
}
