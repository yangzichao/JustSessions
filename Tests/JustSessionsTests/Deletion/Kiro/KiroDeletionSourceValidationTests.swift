import Foundation
import Testing
@testable import JustSessions

struct KiroDeletionSourceValidationTests {
    @Test(arguments: ["json", "jsonl"])
    func refusesMissingSessionFilesBeforeRunningTheCLI(_ missingExtension: String) throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.sessionsDirectory
            .appendingPathComponent("\(fixture.conversation.sessionID).\(missingExtension)"))
        try expectRefused(fixture.conversation, in: fixture, error: .missingSource)
    }

    @Test func refusesOtherProvidersHostsIDsAndFileNames() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        for conversation in [
            Conversation.fixture(provider: .claude, sessionID: fixture.conversation.sessionID, sourceFile: fixture.conversation.sourceFile),
            fixture.conversation.onHost(.ssh("devbox")),
            .fixture(provider: .kiro, sessionID: "../../elsewhere", sourceFile: fixture.conversation.sourceFile),
            .fixture(provider: .kiro, sessionID: UUID().uuidString, sourceFile: fixture.conversation.sourceFile),
        ] {
            try expectRefused(conversation, in: fixture)
        }
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test(arguments: ["session_id", "cwd"])
    func refusesMetadataThatDescribesAnotherSessionOrProject(_ changedField: String) throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        var metadata = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: fixture.metadataFile)) as? [String: Any])
        metadata[changedField] = changedField == "session_id" ? UUID().uuidString : "/another/project"
        try JSONSerialization.data(withJSONObject: metadata).write(to: fixture.metadataFile)

        try expectRefused(fixture.conversation, in: fixture)

        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test(arguments: ["json", "jsonl"])
    func refusesSymlinksOutsideTheConfiguredHistory(_ linkedExtension: String) throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let sessionFile = fixture.sessionsDirectory.appendingPathComponent("\(fixture.conversation.sessionID).\(linkedExtension)")
        let outsideFile = fixture.root.appendingPathComponent("outside.\(linkedExtension)")
        try FileManager.default.moveItem(at: sessionFile, to: outsideFile)
        try FileManager.default.createSymbolicLink(at: sessionFile, withDestinationURL: outsideFile)

        try expectRefused(fixture.conversation, in: fixture)

        #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    }

    @Test func refusesAHistoryFileOutsideTheConfiguredFolder() throws {
        let fixture = try KiroHomeFixture()
        defer { fixture.remove() }
        let outsideDirectory = fixture.root.appendingPathComponent("elsewhere")
        try KiroSessionFolderFixture(sessionsDirectory: outsideDirectory).writeSession(
            id: fixture.conversation.sessionID,
            projectPath: fixture.projectDirectory.path,
            messageLines: [KiroSessionFolderFixture.prompt("Keep me")]
        )
        let outsideFile = outsideDirectory.appendingPathComponent("\(fixture.conversation.sessionID).jsonl")
        let outsideConversation = Conversation.fixture(
            provider: .kiro,
            sessionID: fixture.conversation.sessionID,
            projectPath: fixture.projectDirectory.path,
            sourceFile: outsideFile
        )

        try expectRefused(outsideConversation, in: fixture)

        #expect(FileManager.default.fileExists(atPath: outsideFile.path))
    }

    private func expectRefused(
        _ conversation: Conversation,
        in fixture: KiroHomeFixture,
        error: ConversationDeletionError = .invalidSource
    ) throws {
        let markerFile = fixture.root.appendingPathComponent("cli-ran")
        #expect(throws: error) {
            try fixture.delete(conversation, runningScript: "#!/bin/sh\n/usr/bin/touch \(ShellQuoting.quoted(markerFile.path))\n")
        }
        #expect(!FileManager.default.fileExists(atPath: markerFile.path))
    }
}
