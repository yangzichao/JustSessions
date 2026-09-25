import Foundation
import Testing
@testable import JustSessions

struct HostModelTests {
    @Test func hostListAcceptsSSHDestinationsAndRejectsUnsafeOnes() {
        var hostList = RemoteHostList()
        let addResults = [
            "  devbox  ", "me@devbox.example.com", "devbox", "-oProxyCommand=evil", "two words", "host/path", "   ",
        ].map { hostList.add($0) }
        #expect(addResults == [true, true, false, false, false, false, false])
        #expect(hostList.hosts == ["devbox", "me@devbox.example.com"])

        hostList.remove("devbox")
        #expect(hostList.hosts == ["me@devbox.example.com"])
    }

    @Test func sshProjectKeyRoundTripsAndStaysApartFromFoldersOnThisMac() {
        let onDevbox = ProjectLocation(host: .ssh("me@devbox"), path: "/home/me/paper")
        #expect(onDevbox.key == "ssh://me@devbox/home/me/paper")
        #expect(ProjectLocation(key: onDevbox.key) == onDevbox)
        #expect(onDevbox.copyablePath == "me@devbox:/home/me/paper")
        #expect(!onDevbox.folderExistsOnThisMac)
        #expect(onDevbox.canStartSessions)

        let onThisMac = ProjectLocation(key: "/Users/me/paper")
        #expect(onThisMac == ProjectLocation(host: .thisMac, path: "/Users/me/paper"))
        #expect(onThisMac.copyablePath == "/Users/me/paper")
        #expect(ProjectLocation(key: "ssh://devbox").host == .thisMac)
        #expect(ProjectLocation(key: "ssh:///home/me").host == .thisMac)
    }

    @Test func folderOnThisMacIsKeyedByItsResolvedPath() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("paper")
        let link = root.appendingPathComponent("paper-link")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: folder)

        let throughLink = ProjectLocation(host: .thisMac, path: link.path)
        #expect(throughLink.key == folder.resolvingSymlinksInPath().path)
        #expect(throughLink.folderExistsOnThisMac)
        #expect(throughLink.canStartSessions)
        #expect(!ProjectLocation(host: .thisMac, path: root.appendingPathComponent("gone").path).canStartSessions)
    }

    @Test func sessionsOnThisMacKeepTheirIDsAndSSHSessionsAddTheirHost() {
        let sessionID = UUID().uuidString
        let onThisMac = conversation(sessionID: sessionID, project: "/Users/me/paper")
        let onDevbox = onThisMac.onHost(.ssh("devbox"))

        #expect(onThisMac.id == "Claude Code:\(sessionID)")
        #expect(onDevbox.id == "Claude Code:\(sessionID)@devbox")
        #expect(onDevbox.projectDirectoryKey == "ssh://devbox/Users/me/paper")
        #expect(onDevbox.isProjectAvailable)
        #expect(onDevbox.supportsDeletionFromLauncher)
        #expect(onDevbox.withSuggestedTitle("Renamed").host == .ssh("devbox"))

        let groups = ProjectConversationGroup.grouped([onThisMac, onDevbox])
        #expect(groups.count == 2)
        let devboxGroup = groups.first { $0.host == .ssh("devbox") }
        #expect(devboxGroup?.location.path == "/Users/me/paper")
        #expect(devboxGroup?.folderName == "paper")
        #expect(devboxGroup?.canStartNewSession == true)
        #expect(devboxGroup?.newSessionProviders == [.claude, .codex])
    }

    @Test func hostNamesReadWithinASentence() {
        #expect("End on \(SessionHost.thisMac.nameInSentence)" == "End on this Mac")
        #expect("End on \(SessionHost.ssh("me@devbox").nameInSentence)" == "End on me@devbox")
    }

    @Test func everyToolRunsOnThisMacAndAntigravityOnlyThere() {
        #expect(ConversationProvider.allCases.filter { $0.runs(on: .thisMac) } == [.claude, .codex, .antigravity])
        #expect(ConversationProvider.allCases.filter { $0.runs(on: .ssh("devbox")) } == [.claude, .codex])
    }

    @Test func sidebarListsEveryHostInOrderIncludingOnesWithoutProjects() {
        let onThisMac = conversation(project: "/Users/me/app", minutesAgo: 30)
        let onDevbox = [
            conversation(project: "/home/me/api", minutesAgo: 1),
            conversation(project: "/home/me/infra", minutesAgo: 60),
        ].map { $0.onHost(.ssh("devbox")) }
        let projects = ProjectConversationGroup.grouped(onDevbox + [onThisMac])

        let sections = HostProjectSection.sections(hosts: [.thisMac, .ssh("devbox"), .ssh("laptop")], projects: projects)

        #expect(sections.map(\.host) == [.thisMac, .ssh("devbox"), .ssh("laptop")])
        #expect(sections[0].projects.map(\.location.path) == ["/Users/me/app"])
        #expect(sections[1].projects.map(\.location.path) == ["/home/me/api", "/home/me/infra"])
        #expect(sections[2].projects.isEmpty)
    }

    @Test func syncAgeReadsLikeTheSessionAges() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let locale = Locale(identifier: "en_US")
        /// 2026-09-25 12:00:00 UTC.
        let now = Date(timeIntervalSince1970: 1_790_337_600)
        func syncAge(secondsAgo: TimeInterval) -> String {
            HostSyncAgeFormatter.string(
                forSyncedAt: now.addingTimeInterval(-secondsAgo),
                relativeTo: now,
                calendar: calendar,
                locale: locale
            )
        }

        #expect(syncAge(secondsAgo: 20) == "synced just now")
        #expect(syncAge(secondsAgo: 5 * 60) == "synced 5m ago")
        #expect(syncAge(secondsAgo: 3 * 60 * 60) == "synced 3h ago")
        #expect(syncAge(secondsAgo: 7 * 24 * 60 * 60) == "synced Sep 18")
    }

    private func conversation(
        sessionID: String = UUID().uuidString,
        project: String,
        minutesAgo: Double = 0
    ) -> Conversation {
        Conversation(
            provider: .claude,
            sessionID: sessionID,
            projectPath: project,
            suggestedTitle: "Session",
            updatedAt: Date(timeIntervalSinceNow: -minutesAgo * 60),
            sourceFile: URL(fileURLWithPath: "/tmp/\(sessionID).jsonl")
        )
    }
}
