import Foundation
import Testing

@testable import JustSessions

struct HostCheckReportTests {
    @Test func plainTextStartsWithThisMacAndShowsWhatToFixFirst() {
        let report = HostCheckReport(
            host: "devbox",
            checkedAt: Date(timeIntervalSince1970: 0),
            thisMacSummary: "JustSessions 1.2.10 · macOS 26.0.1 · OpenSSH_10.3p1",
            findings: [
                HostCheckFinding(id: .rsync, status: .passed, title: "rsync", summary: "Copies devbox's sessions to this Mac."),
                HostCheckFinding(
                    id: .cli(.opencode),
                    status: .warning,
                    title: "OpenCode",
                    summary: "Found at /usr/bin/opencode, but it failed when asked for its version.",
                    hostOutput: "env: node: No such file or directory\nsecond line",
                    commandToRunYourself: "ssh devbox 'command -v opencode'"
                ),
            ]
        )

        let lines = report.plainText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines[0] == "JustSessions host check: devbox")
        #expect(lines[2] == "This Mac: JustSessions 1.2.10 · macOS 26.0.1 · OpenSSH_10.3p1")
        #expect(
            Array(lines[4...]) == [
                "[Warning] OpenCode: Found at /usr/bin/opencode, but it failed when asked for its version.",
                "    devbox printed:",
                "      env: node: No such file or directory",
                "      second line",
                "    Run it yourself: ssh devbox 'command -v opencode'",
                "[OK] rsync: Copies devbox's sessions to this Mac.",
                "",
            ])
        #expect(report.problemCount == 0)
        #expect(report.warningCount == 1)
    }

    @Test func plainTextEndsWithWhatTheEndedTabShowed() {
        let report = HostCheckReport(
            host: "devbox",
            checkedAt: Date(timeIntervalSince1970: 0),
            thisMacSummary: "",
            findings: [HostCheckFinding(id: .rsync, status: .passed, title: "rsync", summary: "Found.")],
            endedTabScreen: "protocol version mismatch (client 8, server 7)\n\nConnection to devbox closed."
        )

        let lines = report.plainText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        #expect(
            Array(lines.suffix(6)) == [
                "",
                "What the tab showed when it ended:",
                "    protocol version mismatch (client 8, server 7)",
                "    ",
                "    Connection to devbox closed.",
                "",
            ])
        #expect(report.hasSomethingToFix)
    }

    @Test func theHostsProblemsLeaveOutTheFolder() {
        let report = HostCheckReport(
            host: "devbox",
            checkedAt: Date(timeIntervalSince1970: 0),
            thisMacSummary: "",
            findings: [
                HostCheckFinding(id: .folder, status: .problem, title: "Folder", summary: ""),
                HostCheckFinding(id: .tmux, status: .problem, title: "tmux", summary: ""),
                HostCheckFinding(id: .rsync, status: .passed, title: "rsync", summary: ""),
            ]
        )
        #expect(report.hostProblems.map(\.id) == [.tmux])
        #expect(report.hasSomethingToFix)
        #expect(!HostCheckReport(host: "devbox", checkedAt: .now, thisMacSummary: "", findings: []).hasSomethingToFix)
    }

    @Test func problemsComeBeforeWarningsAndTheRestKeepTheirOrder() {
        let statuses: [HostCheckFinding.Status] = [.passed, .warning, .note, .problem, .passed, .warning]
        let report = HostCheckReport(
            host: "devbox",
            checkedAt: Date(timeIntervalSince1970: 0),
            thisMacSummary: "",
            findings: statuses.enumerated().map { index, status in
                HostCheckFinding(id: HostCheckFindingID.all[index], status: status, title: "", summary: "")
            }
        )
        #expect(report.findingsMostImportantFirst.map(\.id) == [3, 1, 5, 0, 2, 4].map { HostCheckFindingID.all[$0] })
    }
}
