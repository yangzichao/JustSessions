import Foundation

struct HostCheckReport: Codable, Equatable, Sendable {
    let host: String
    let checkedAt: Date
    let thisMacSummary: String
    let findings: [HostCheckFinding]
    var endedTabScreen: String? = nil

    var problemCount: Int { findings.count { $0.status == .problem } }
    var warningCount: Int { findings.count { $0.status == .warning } }

    var hostProblems: [HostCheckFinding] {
        findings.filter { $0.status == .problem && $0.id != "folder" }
    }

    var hasSomethingToFix: Bool {
        problemCount + warningCount > 0 || endedTabScreen != nil
    }

    var findingsMostImportantFirst: [HostCheckFinding] {
        findings.filter { $0.status == .problem }
            + findings.filter { $0.status == .warning }
            + findings.filter { $0.status != .problem && $0.status != .warning }
    }

    var plainText: String {
        var lines = [
            AppLocalization.string("JustSessions host check: \(host)"),
            checkedAt.formatted(date: .numeric, time: .shortened),
            AppLocalization.string("This Mac: \(thisMacSummary)"),
            "",
        ]
        for finding in findingsMostImportantFirst {
            lines.append("[\(Self.label(for: finding.status))] \(finding.title): \(finding.summary)")
            if let hostOutput = finding.hostOutput, !hostOutput.isEmpty {
                lines.append("    " + AppLocalization.string("\(host) printed:"))
                lines += Self.indented(hostOutput, by: 6)
            }
            if let command = finding.commandToRunYourself {
                lines.append("    " + AppLocalization.string("Run it yourself: \(command)"))
            }
        }
        if let endedTabScreen {
            lines += ["", AppLocalization.string("What the tab showed when it ended:")]
            lines += Self.indented(endedTabScreen, by: 4)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func label(for status: HostCheckFinding.Status) -> String {
        switch status {
        case .passed: AppLocalization.string("OK")
        case .note: AppLocalization.string("Note")
        case .warning: AppLocalization.string("Warning")
        case .problem: AppLocalization.string("Problem")
        }
    }

    static func indented(_ text: String, by spaces: Int) -> [String] {
        let indent = String(repeating: " ", count: spaces)
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { indent + $0 }
    }
}
