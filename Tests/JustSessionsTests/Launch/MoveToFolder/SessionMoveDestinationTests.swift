import Foundation
import Testing

@testable import JustSessions

/// Move to lists the other projects on the session's host whose folder a session can start in, in the sidebar's order.
struct SessionMoveDestinationTests {
    @Test func listsTheOtherProjectsOnTheSessionsHostInSidebarOrder() {
        let session = Conversation.fixture(projectPath: "/home/me/api", updatedAt: .now, host: .ssh("devbox"))
        let projects = ProjectConversationGroup.grouped([
            session,
            Conversation.fixture(projectPath: "/home/me/old", updatedAt: .now.addingTimeInterval(-600), host: .ssh("devbox")),
            Conversation.fixture(projectPath: "/home/me/web", updatedAt: .now.addingTimeInterval(-60), host: .ssh("devbox")),
            Conversation.fixture(projectPath: "/home/me/web", updatedAt: .now, host: .ssh("cloud")),
        ])

        let destinations = SessionMoveDestination.destinations(for: session, among: projects)

        #expect(destinations.map(\.folderPath) == ["/home/me/web", "/home/me/old"])
        #expect(destinations.map(\.menuTitle) == ["web", "old"])
    }

    @Test func leavesOutFoldersGoneFromThisMacAndTellsSameNamedProjectsApart() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let ownFolder = root.appendingPathComponent("api")
        let workApp = root.appendingPathComponent("work/app")
        let homeApp = root.appendingPathComponent("home/app")
        for folder in [ownFolder, workApp, homeApp] {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        let session = Conversation.fixture(projectPath: ownFolder.path, updatedAt: .now)
        let projects = ProjectConversationGroup.grouped([
            session,
            Conversation.fixture(projectPath: workApp.path, updatedAt: .now.addingTimeInterval(-60)),
            Conversation.fixture(projectPath: homeApp.path, updatedAt: .now.addingTimeInterval(-120)),
            Conversation.fixture(projectPath: root.appendingPathComponent("gone").path, updatedAt: .now),
        ])

        let destinations = SessionMoveDestination.destinations(for: session, among: projects)

        #expect(destinations.map(\.folderPath) == [workApp.path, homeApp.path].map(Self.resolved))
        #expect(destinations.map(\.parentLabel) == [Self.parentLabel(of: workApp), Self.parentLabel(of: homeApp)])
        #expect(destinations.first?.menuTitle == "app — \(Self.parentLabel(of: workApp))")
    }

    /// Project keys on this Mac resolve symbolic links, such as `/var` to `/private/var`.
    private static func resolved(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    }

    private static func parentLabel(of folder: URL) -> String {
        ProjectParentLabels.parentLabel(forFolderPath: resolved(folder.path))
    }
}
