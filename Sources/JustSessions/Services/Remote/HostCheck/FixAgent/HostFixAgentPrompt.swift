import Foundation

enum HostFixAgentPrompt {
    static func task(for report: HostCheckReport, facts: HostFixAgentHostFacts) -> String {
        var lines = [
            "Fix what JustSessions' host check found on \(report.host).",
            "",
            "JustSessions is a macOS app that lists, resumes, and starts sessions of AI coding CLIs (Claude Code, Codex, "
                + "Antigravity, Kiro CLI, OpenCode, Pi) on the Mac and on SSH hosts. Its check of \(report.host) found "
                + "what follows. Find out why, explain it to the user in a few sentences, and fix it with them.",
            "",
            "## What the check found",
            "",
            report.plainText.trimmingCharacters(in: .newlines),
            "",
            "## How JustSessions uses \(report.host)",
            "",
        ]
        lines += facts.lines
        lines += [
            "",
            "## Rules",
            "",
            "- Run the check's commands first and read what they print. Change nothing until you know the cause.",
            "- Ask the user before you end tmux sessions or a tmux server, stop processes, install, upgrade, or remove "
                + "packages, or edit shell startup files. Before ending a tmux server, list its sessions with the tmux "
                + "that started it, and tell the user which are their own rather than JustSessions'.",
            "- Change only what the fix needs, and tell the user what you changed and how to undo it.",
            "- If the cause is in JustSessions rather than on the host, say so and draft an issue for "
                + "\(AppLinks.newGitHubIssueURL.absoluteString) with the report, instead of working around it.",
            "- Once it's fixed, ask the user to click Check again in JustSessions' host check.",
        ]
        return lines.joined(separator: "\n")
    }

    static func message(
        task: String,
        machine: HostFixAgentMachine,
        host: String,
        folder: String,
        guideSections: [JustSessionsGuideSection],
        appVersion: String,
        guideText: (JustSessionsGuideSection) -> String? = { JustSessionsGuideText.text(of: $0) }
    ) -> String {
        var parts = [whereYouRun(machine: machine, host: host, folder: folder), task.trimmingCharacters(in: .whitespacesAndNewlines)]
        let gitReference = JustSessionsGuideText.gitReference(forAppVersion: appVersion)
        let sectionTexts = guideSections.compactMap { section in guideText(section).map { (section, $0) } }
        if !sectionTexts.isEmpty {
            let guidesURL = AppLinks.gitHubRepositoryURL.appendingPathComponent("tree/\(gitReference)/docs/guides")
            var guideLines = [
                "## JustSessions' guides",
                "",
                "From the guides of JustSessions \(appVersion); all of them are at \(guidesURL.absoluteString).",
            ]
            for (section, text) in sectionTexts {
                guideLines += [
                    "",
                    "### \(section.fileName): \(section.heading)",
                    "",
                    "Source: \(section.link(gitReference: gitReference).absoluteString)",
                    "",
                    withoutHeadingLine(text),
                ]
            }
            parts.append(guideLines.joined(separator: "\n"))
        }
        return parts.joined(separator: "\n\n") + "\n"
    }

    static func whereYouRun(machine: HostFixAgentMachine, host: String, folder: String) -> String {
        switch machine {
        case .checkedHost:
            "JustSessions started you on \(host), in \(folder), straight in the user's login shell rather than in tmux, "
                + "so you keep running whatever state tmux is in. The check's \"Run it yourself\" commands run from the "
                + "user's Mac through ssh; here, run the command inside their quotes."
        case .thisMac:
            "JustSessions started you on the user's Mac, in \(folder), outside tmux. \(host) is another machine: reach it "
                + "with `ssh \(host)`, as the check's \"Run it yourself\" commands do. JustSessions' own tmux on this Mac "
                + "(`-L justsessions`) is not what the check is about."
        }
    }

    private static func withoutHeadingLine(_ sectionText: String) -> String {
        sectionText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .dropFirst()
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
