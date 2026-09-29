import Foundation
import Testing
@testable import JustSessions

struct ProjectDisplayNamesTests {
    private let projectPath = "/tmp/example-project"

    @Test func defaultsToTheFolderName() {
        let displayNames = ProjectDisplayNames()

        #expect(displayNames.displayName(forProjectPath: projectPath) == "example-project")
        #expect(!displayNames.hasCustomName(forProjectPath: projectPath))
    }

    @Test func renameStoresATrimmedCustomName() {
        var displayNames = ProjectDisplayNames()

        displayNames.rename(projectPath: projectPath, to: "  Marketing site  ")

        #expect(displayNames.displayName(forProjectPath: projectPath) == "Marketing site")
        #expect(displayNames.hasCustomName(forProjectPath: projectPath))
    }

    @Test func emptyNameOrFolderNameClearsTheCustomName() {
        var displayNames = ProjectDisplayNames(customNamesByProjectPath: [projectPath: "Marketing site"])

        displayNames.rename(projectPath: projectPath, to: "   ")
        #expect(!displayNames.hasCustomName(forProjectPath: projectPath))

        displayNames.rename(projectPath: projectPath, to: "Marketing site")
        displayNames.rename(projectPath: projectPath, to: "example-project")
        #expect(!displayNames.hasCustomName(forProjectPath: projectPath))
    }

    @Test func customNamesSurviveASaveAndLoad() throws {
        let isolatedUserDefaults = try IsolatedUserDefaults()
        defer { isolatedUserDefaults.removeSuite() }
        let userDefaults = isolatedUserDefaults.userDefaults
        var displayNames = ProjectDisplayNames()
        displayNames.rename(projectPath: projectPath, to: "Marketing site")

        displayNames.save(to: userDefaults)

        #expect(ProjectDisplayNames.load(from: userDefaults) == displayNames)
    }

    @Test func groupedProjectsUseCustomNames() {
        let conversation = Conversation(
            provider: .claude,
            sessionID: UUID().uuidString,
            projectPath: projectPath,
            suggestedTitle: "Example",
            updatedAt: .now,
            sourceFile: URL(fileURLWithPath: "/tmp/example.jsonl")
        )
        var displayNames = ProjectDisplayNames()
        displayNames.rename(projectPath: conversation.projectDirectoryKey, to: "Marketing site")

        let groups = ProjectConversationGroup.grouped([conversation], displayNames: displayNames)

        #expect(groups.map(\.displayName) == ["Marketing site"])
        #expect(groups.map(\.folderName) == ["example-project"])
    }
}
