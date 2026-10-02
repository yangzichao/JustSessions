import Foundation
import Testing
@testable import JustSessions

struct PiConversationDeletionTests {
    @Test func movesTheSessionFileAndTheFolderBesideItToTheTrash() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        let companionDirectory = sessionFile.deletingPathExtension()
        try FileManager.default.createDirectory(at: companionDirectory.appendingPathComponent("run-1"), withIntermediateDirectories: true)
        try "child".write(to: companionDirectory.appendingPathComponent("run-1/session.jsonl"), atomically: true, encoding: .utf8)
        let keptFile = try sandbox.folder.writeSession(id: UUID().uuidString.lowercased(), projectPath: "/Users/me/app")

        try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))

        #expect(!FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(!FileManager.default.fileExists(atPath: companionDirectory.path))
        #expect(FileManager.default.fileExists(atPath: keptFile.path))
        #expect(sandbox.trashedNames == [sessionFile.lastPathComponent, companionDirectory.lastPathComponent].sorted())
        #expect(FileManager.default.fileExists(
            atPath: sandbox.trashDirectory.appendingPathComponent("\(companionDirectory.lastPathComponent)/run-1/session.jsonl").path
        ))
    }

    @Test func aSessionWithoutAFolderMovesOnlyItsFile() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")

        try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))

        #expect(!FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames == [sessionFile.lastPathComponent])
    }

    @Test func aSessionDirectlyInACustomSessionsFolderIsDeleted() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app", inProjectFolder: false)
        try FileManager.default.createDirectory(at: sessionFile.deletingPathExtension(), withIntermediateDirectories: true)

        try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))

        #expect(sandbox.trashedNames == [sessionFile.lastPathComponent, sessionFile.deletingPathExtension().lastPathComponent].sorted())
    }

    @Test func aFolderBesideTheSessionThatIsASymbolicLinkIsLeftAlone() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        let elsewhere = sandbox.root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: sessionFile.deletingPathExtension(), withDestinationURL: elsewhere)

        try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))

        #expect(sandbox.trashedNames == [sessionFile.lastPathComponent])
        #expect(FileManager.default.fileExists(atPath: elsewhere.path))
    }

    @Test func refusesASessionFileOutsideTheSessionsFolderOrNestedDeeper() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let outside = try PiSessionFolderFixture(sessionsDirectory: sandbox.root.appendingPathComponent("other"))
            .writeSession(id: sessionID, projectPath: "/Users/me/app")
        let nested = try PiSessionFolderFixture(sessionsDirectory: sandbox.folder.sessionsDirectory.appendingPathComponent("--Users-me-app--/stem/forks"))
            .writeSession(id: sessionID, projectPath: "/Users/me/app", inProjectFolder: false)

        for sourceFile in [outside, nested] {
            #expect(throws: ConversationDeletionError.invalidSource) {
                try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sourceFile))
            }
            #expect(FileManager.default.fileExists(atPath: sourceFile.path))
        }
        #expect(sandbox.trashedNames.isEmpty)
    }

    @Test func refusesASessionFileThatIsASymbolicLink() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let realFile = try PiSessionFolderFixture(sessionsDirectory: sandbox.root.appendingPathComponent("elsewhere"))
            .writeSession(id: sessionID, projectPath: "/Users/me/app", inProjectFolder: false)
        let projectFolder = sandbox.folder.sessionsDirectory.appendingPathComponent("--Users-me-app--")
        try FileManager.default.createDirectory(at: projectFolder, withIntermediateDirectories: true)
        let link = projectFolder.appendingPathComponent(realFile.lastPathComponent)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: realFile)

        #expect(throws: ConversationDeletionError.sourceMismatch) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: link))
        }
        #expect(FileManager.default.fileExists(atPath: realFile.path))
        #expect(sandbox.trashedNames.isEmpty)
    }

    @Test func refusesAnotherToolsSession() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")

        #expect(throws: ConversationDeletionError.invalidSource) {
            try sandbox.deletion.delete(.fixture(provider: .claude, sessionID: sessionID, sourceFile: sessionFile))
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
    }

    @Test func refusesAFileWhoseNameOrHeaderNamesAnotherSession() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let headerID = UUID().uuidString.lowercased()
        let fileNameID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: headerID, projectPath: "/Users/me/app", fileSessionID: fileNameID)

        #expect(throws: ConversationDeletionError.invalidSource) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: headerID, sourceFile: sessionFile))
        }
        #expect(throws: ConversationDeletionError.sourceMismatch) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: fileNameID, sourceFile: sessionFile))
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames.isEmpty)
    }

    @Test func refusesASessionIDThatIsNotAUUID() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = "not-a-uuid"
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")

        #expect(throws: ConversationDeletionError.invalidSource) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames.isEmpty)
    }

    /// `SESSION_ID` stands for the session's id.
    @Test(arguments: [
        #"{"type":"message","id":"SESSION_ID","parentId":null,"timestamp":"2026-09-30T10:00:00.000Z"}"# + "\n",
        #"{"type":"session","version":3,"id":7,"cwd":"/Users/me/app"}"# + "\n",
        #"{"type":["session"],"id":"SESSION_ID"}"# + "\n",
        #"[{"type":"session","id":"SESSION_ID"}]"# + "\n",
        "not json\n",
        // A header whose line never ends, or a file with no lines.
        #"{"type":"session","version":3,"id":"SESSION_ID","cwd":"/Users/me/app"}"#,
        "",
    ])
    func refusesAFileWhoseFirstLineIsNotASessionHeader(contents: String) throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        try contents.replacingOccurrences(of: "SESSION_ID", with: sessionID).write(to: sessionFile, atomically: true, encoding: .utf8)

        #expect(throws: ConversationDeletionError.sourceMismatch) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames.isEmpty)
    }

    @Test func aFolderThatCannotBeMovedLeavesTheSessionUntouched() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        let companionDirectory = sessionFile.deletingPathExtension()
        try FileManager.default.createDirectory(at: companionDirectory, withIntermediateDirectories: true)
        let deletion = sandbox.deletion { $0.pathExtension != "jsonl" }

        #expect(throws: PiDeletionSandbox.MoveRefused()) {
            try deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(FileManager.default.fileExists(atPath: companionDirectory.path))
        #expect(sandbox.trashedNames.isEmpty)
    }

    @Test func aFileThatCannotBeMovedKeepsTheSessionAndDeletingAgainFinishes() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        let companionDirectory = sessionFile.deletingPathExtension()
        try FileManager.default.createDirectory(at: companionDirectory, withIntermediateDirectories: true)
        let conversation = Conversation.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile)

        #expect(throws: PiDeletionSandbox.MoveRefused()) {
            try sandbox.deletion { $0.pathExtension == "jsonl" }.delete(conversation)
        }
        #expect(FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames == [companionDirectory.lastPathComponent])

        try sandbox.deletion.delete(conversation)

        #expect(!FileManager.default.fileExists(atPath: sessionFile.path))
        #expect(sandbox.trashedNames == [sessionFile.lastPathComponent, companionDirectory.lastPathComponent].sorted())
    }

    @Test func aSessionFileThatIsAlreadyGoneIsReportedMissing() throws {
        let sandbox = try PiDeletionSandbox()
        defer { sandbox.remove() }
        let sessionID = UUID().uuidString.lowercased()
        let sessionFile = try sandbox.folder.writeSession(id: sessionID, projectPath: "/Users/me/app")
        try FileManager.default.removeItem(at: sessionFile)

        #expect(throws: ConversationDeletionError.missingSource) {
            try sandbox.deletion.delete(.fixture(provider: .pi, sessionID: sessionID, sourceFile: sessionFile))
        }
    }
}
