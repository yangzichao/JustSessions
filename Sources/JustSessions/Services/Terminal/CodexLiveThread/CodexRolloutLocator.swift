import Foundation

/// Finds the rollout file of a Codex thread from the start of its id, as a Codex terminal title shows it; see
/// `CodexThreadTitle`. Codex files each rollout under the day the thread started,
/// `sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl`.
struct CodexRolloutLocator: Sendable {
    let sessionsDirectory: URL
    var calendar = Calendar.current

    init(codexDirectory: URL = CodexAdapter.defaultCodexDirectory) {
        self.sessionsDirectory = codexDirectory.appendingPathComponent("sessions")
    }

    /// The full id of the thread, once its rollout file opens with a complete `session_meta` line. Looks back day by
    /// day from the newest to the day before `earliestStart`, since a refresh that started then listed the threads
    /// already saved; with no `earliestStart`, through every day.
    func sessionID(forThreadIDPrefix threadIDPrefix: String, startedOnOrAfter earliestStart: Date?) -> String? {
        let earliestDay = earliestStart
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) }
            .map { calendar.dateComponents([.year, .month, .day], from: $0) }
            .map { [$0.year ?? 0, $0.month ?? 0, $0.day ?? 0] } ?? [0, 0, 0]
        for dayDirectory in dayDirectoriesNewestFirst(notBefore: earliestDay) {
            guard let fileNames = try? FileManager.default.contentsOfDirectory(atPath: dayDirectory.path) else { continue }
            for fileName in fileNames
            where fileName.hasPrefix("rollout-") && fileName.hasSuffix(".jsonl") && fileName.contains("-\(threadIDPrefix)") {
                if let head = CodexRolloutHead(file: dayDirectory.appendingPathComponent(fileName)),
                   head.sessionID.hasPrefix(threadIDPrefix) {
                    return head.sessionID
                }
            }
        }
        return nil
    }

    /// Days are `[year, month, day]`.
    private func dayDirectoriesNewestFirst(notBefore earliestDay: [Int]) -> [URL] {
        var dayDirectories: [(day: [Int], directory: URL)] = []
        for (year, yearDirectory) in numberedSubdirectories(of: sessionsDirectory) where year >= earliestDay[0] {
            for (month, monthDirectory) in numberedSubdirectories(of: yearDirectory) {
                for (day, dayDirectory) in numberedSubdirectories(of: monthDirectory)
                where !([year, month, day].lexicographicallyPrecedes(earliestDay)) {
                    dayDirectories.append(([year, month, day], dayDirectory))
                }
            }
        }
        return dayDirectories
            .sorted { $1.day.lexicographicallyPrecedes($0.day) }
            .map(\.directory)
    }

    private func numberedSubdirectories(of directory: URL) -> [(number: Int, directory: URL)] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.compactMap { name in
            Int(name).map { ($0, directory.appendingPathComponent(name)) }
        }
    }
}
