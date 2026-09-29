import Foundation
import Testing
@testable import JustSessions

struct ClaudeSessionsIndexTests {
    @Test func entriesAreFoundBySessionID() throws {
        let index = ClaudeSessionsIndex(jsonData: Data(#"""
        {
          "originalPath": "/Users/me/code/app",
          "entries": [
            {"sessionId": "a", "projectPath": "/Users/me/code/app/Sources", "customTitle": "Renamed",
             "firstPrompt": "Fix the build", "modified": "2026-09-24T10:00:00Z", "isSidechain": false},
            {"sessionId": "b", "isSidechain": true},
            {"projectPath": "/Users/me/code/no-session-id"}
          ]
        }
        """#.utf8))

        let entry = try #require(index.entry(forSessionID: "a"))
        #expect(entry.projectPath == "/Users/me/code/app/Sources")
        #expect(entry.customTitle == "Renamed")
        #expect(entry.firstPrompt == "Fix the build")
        #expect(entry.modifiedAt == ConversationMetadata.date("2026-09-24T10:00:00Z"))
        #expect(!entry.isSidechain)
        #expect(index.entry(forSessionID: "b")?.isSidechain == true)
        #expect(index.entry(forSessionID: "c") == nil)
        #expect(index.originalProjectPath == "/Users/me/code/app")
    }

    @Test func aLaterEntryForTheSameSessionWins() {
        let index = ClaudeSessionsIndex(jsonData: Data(
            #"{"entries": [{"sessionId": "a", "firstPrompt": "Old"}, {"sessionId": "a", "firstPrompt": "New"}]}"#.utf8
        ))

        #expect(index.entry(forSessionID: "a")?.firstPrompt == "New")
    }

    @Test(arguments: ["", "not json", "[]", #"{"entries": "not a list"}"#])
    func anIndexThatCannotBeReadHasNoEntries(_ contents: String) {
        let index = ClaudeSessionsIndex(jsonData: Data(contents.utf8))

        #expect(index.entry(forSessionID: "a") == nil)
        #expect(index.originalProjectPath == nil)
    }

    @Test func aProjectFolderWithoutAnIndexHasNoEntries() throws {
        let projectDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: projectDirectory) }

        let index = ClaudeSessionsIndex(projectDirectory: projectDirectory)
        #expect(index.entry(forSessionID: "a") == nil)
        #expect(index.originalProjectPath == nil)
    }
}
