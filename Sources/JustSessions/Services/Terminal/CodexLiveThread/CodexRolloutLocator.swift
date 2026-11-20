import Foundation

/// Codex files each rollout under the day the thread started, `sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl`.
struct CodexRolloutLocator: Sendable {
    let sessionsDirectory: URL
    var calendar = Calendar.current

    init(codexDirectory: URL = CodexAdapter.defaultCodexDirectory) {
        self.sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
    }

    func sessionID(forThreadIDPrefix threadIDPrefix: String, startedOnOrAfter earliestStart: Date?) -> String? {
        let dayBeforeEarliestStart =
            earliestStart
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            .map { CodexRolloutDay(of: $0, in: calendar) }
        for dayDirectory in dayDirectoriesNewestFirst(notBefore: dayBeforeEarliestStart ?? .beforeEveryRollout) {
            guard let fileNames = try? FileManager.default.contentsOfDirectory(atPath: dayDirectory.path) else { continue }
            for fileName in fileNames
            where fileName.hasPrefix("rollout-") && fileName.hasSuffix(".jsonl") && fileName.contains("-\(threadIDPrefix)") {
                if let head = CodexRolloutHead(file: dayDirectory.appendingPathComponent(fileName)),
                    head.sessionID.hasPrefix(threadIDPrefix)
                {
                    return head.sessionID
                }
            }
        }
        return nil
    }

    private func dayDirectoriesNewestFirst(notBefore earliestDay: CodexRolloutDay) -> [URL] {
        var dayDirectories: [(day: CodexRolloutDay, directory: URL)] = []
        for (year, yearDirectory) in numberedSubdirectories(of: sessionsDirectory) where year >= earliestDay.year {
            for (month, monthDirectory) in numberedSubdirectories(of: yearDirectory) {
                for (day, dayDirectory) in numberedSubdirectories(of: monthDirectory) {
                    let rolloutDay = CodexRolloutDay(year: year, month: month, day: day)
                    if rolloutDay >= earliestDay { dayDirectories.append((rolloutDay, dayDirectory)) }
                }
            }
        }
        return
            dayDirectories
            .sorted { $1.day < $0.day }
            .map(\.directory)
    }

    private func numberedSubdirectories(of directory: URL) -> [(number: Int, directory: URL)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            Int(name).map { ($0, directory.appendingPathComponent(name)) }
        }
    }
}
