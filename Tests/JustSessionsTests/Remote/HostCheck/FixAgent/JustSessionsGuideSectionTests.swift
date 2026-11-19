import Foundation
import Testing

@testable import JustSessions

struct JustSessionsGuideSectionTests {
    /// The headings are the guides' own, so a renamed heading fails here rather than leaving the agent without it.
    @Test(arguments: JustSessionsGuideSection.all)
    func everySectionIsInTheGuidesAndShipsWithTheApp(_ section: JustSessionsGuideSection) throws {
        let guide = try RepositoryFiles.contents(of: "docs/guides/\(section.fileName)")
        let repositoryText = try #require(JustSessionsGuideText.section(headed: section.heading, in: guide))
        #expect(JustSessionsGuideText.text(of: section) == repositoryText)
    }

    /// The guides link to these sections themselves, by the anchors GitHub gives their headings.
    @Test func anchorsAreTheOnesTheGuidesLinkTo() throws {
        let guide = try RepositoryFiles.contents(of: "docs/guides/session-management.md")
        for section in [JustSessionsGuideSection.whenSomethingFailsOnSSHHost, .shellStartupOnSSHHosts, .hostsThatAskForPassword] {
            #expect(guide.contains("](#\(section.anchor))"), "\(section.anchor)")
        }
        #expect(guide.contains("](session-storage.md#\(JustSessionsGuideSection.terminalPersistence.anchor))"))
    }

    @Test func aSectionEndsAtTheNextHeadingOfItsLevelAndSkipsCodeBlocks() {
        let markdown = """
            ## SSH hosts
            Intro.
            ### Shell startup
            Line one.
            ```sh
            # not a heading
            ```
            #### Detail
            More.
            ### Next
            Other.
            """
        #expect(
            JustSessionsGuideText.section(headed: "Shell startup", in: markdown)
                == "### Shell startup\nLine one.\n```sh\n# not a heading\n```\n#### Detail\nMore.")
        #expect(JustSessionsGuideText.section(headed: "Missing", in: markdown) == nil)
    }

    @Test func linksGoToTheReleasesGuidesOrToMainForADevelopmentBuild() {
        #expect(JustSessionsGuideText.gitReference(forAppVersion: "1.2.11") == "v1.2.11")
        #expect(JustSessionsGuideText.gitReference(forAppVersion: "1.2.11-3-gabc1234") == "main")
        #expect(JustSessionsGuideText.gitReference(forAppVersion: "1.2") == "main")
        #expect(
            JustSessionsGuideSection.whenSomethingFailsOnSSHHost.link(gitReference: "v1.2.11").absoluteString
                == "https://github.com/yangzichao/JustSessions/blob/v1.2.11/docs/guides/session-management.md#when-something-fails-on-an-ssh-host"
        )
    }

    @Test func theSectionsAboutAReportFollowItsProblemsAndWarnings() {
        let report = HostCheckReport(
            host: "devbox",
            checkedAt: .now,
            thisMacSummary: "",
            findings: [
                HostCheckFinding(id: "tmux", status: .problem, title: "tmux", summary: ""),
                HostCheckFinding(id: "cli-claude", status: .warning, title: "Claude Code", summary: ""),
                HostCheckFinding(id: "rsync", status: .passed, title: "rsync", summary: ""),
            ]
        )
        #expect(
            JustSessionsGuideSection.sections(about: report)
                == [.whenSomethingFailsOnSSHHost, .terminalPersistence, .cliLaunchAndDiscovery])
    }
}
