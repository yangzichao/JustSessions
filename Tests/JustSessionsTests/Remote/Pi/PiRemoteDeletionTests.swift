import Foundation
import Testing
@testable import JustSessions

/// Runs the deletion script in a local shell whose `$HOME` is a temporary folder standing in for the host's home,
/// under both macOS's `/bin/sh` and dash, the `/bin/sh` of Debian and Ubuntu hosts. Serialized because each case
/// blocks a thread while its shell runs.
@Suite(.serialized)
struct PiRemoteDeletionTests {
    typealias HostShell = RemotePiFixture.HostShell

    /// The script runs as `sh -c …`, so that inner `sh` must be dash too for dash to check it: dash rejects the
    /// bash-only `[[`, which macOS's `/bin/sh` accepts. Skipped without `/bin/dash`, which shows that the other tests
    /// ran only under `/bin/sh`.
    @Test(.enabled(if: HostShell.dash.isInstalled, "Needs /bin/dash, the /bin/sh of Debian and Ubuntu"))
    func underDashTheScriptsOwnShIsDashToo() throws {
        let fixture = try RemotePiFixture(shell: .dash)
        defer { fixture.remove() }

        let result = fixture.runOnHost("sh -c '[[ -n x ]]'")

        #expect(result?.exitStatus == 127)
    }

    @Test(arguments: HostShell.installed)
    func removesTheFolderBesideTheSessionAndItsFileThenDropsTheMirrorCopy(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let runFolder = fixture.hostCompanionFolder.appendingPathComponent("\(UUID().uuidString.lowercased())/run-1")
        try FileManager.default.createDirectory(at: runFolder, withIntermediateDirectories: true)
        try "child".write(to: runFolder.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8)
        let keptFile = try fixture.hostProjectFolder.writeSession(
            id: UUID().uuidString.lowercased(),
            projectPath: "/home/me/paper",
            inProjectFolder: false
        )

        try fixture.deletion().delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.hostCompanionFolder.path))
        #expect(FileManager.default.fileExists(atPath: keptFile.path))
        #expect(!FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test(arguments: HostShell.installed)
    func aSessionWithoutAFolderLosesOnlyItsFile(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }

        try fixture.deletion().delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: fixture.hostProjectFolder.sessionsDirectory.path).isEmpty)
    }

    @Test(arguments: HostShell.installed)
    func aFolderBesideTheSessionThatIsASymbolicLinkIsLeftAlone(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let elsewhere = fixture.root.appendingPathComponent("elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        try "keep".write(to: elsewhere.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: fixture.hostCompanionFolder, withDestinationURL: elsewhere)

        try fixture.deletion().delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: fixture.hostCompanionFolder.path)) == elsewhere.path)
        #expect(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent("notes.txt").path))
    }

    @Test(arguments: HostShell.installed)
    func aSymbolicLinkInPlaceOfTheSessionFileIsRefused(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let target = fixture.root.appendingPathComponent("target.jsonl")
        try FileManager.default.moveItem(at: fixture.hostSessionFile, to: target)
        try FileManager.default.createSymbolicLink(at: fixture.hostSessionFile, withDestinationURL: target)

        let failure = deletionFailure(fixture)

        #expect(failure == "The session file is not a regular file.")
        #expect(FileManager.default.fileExists(atPath: target.path))
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: fixture.hostSessionFile.path)) == target.path)
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test(arguments: HostShell.installed)
    func aProjectFolderThatIsASymbolicLinkIsRefused(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let elsewhere = fixture.root.appendingPathComponent("elsewhere")
        try FileManager.default.moveItem(at: fixture.hostProjectFolder.sessionsDirectory, to: elsewhere)
        try FileManager.default.createSymbolicLink(at: fixture.hostProjectFolder.sessionsDirectory, withDestinationURL: elsewhere)

        #expect(deletionFailure(fixture) == "The project folder is a symbolic link.")
        #expect(FileManager.default.fileExists(atPath: elsewhere.appendingPathComponent(fixture.hostSessionFile.lastPathComponent).path))
    }

    @Test(arguments: HostShell.installed)
    func aFolderInPlaceOfTheSessionFileIsRefused(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.hostSessionFile)
        try FileManager.default.createDirectory(at: fixture.hostSessionFile, withIntermediateDirectories: true)

        #expect(deletionFailure(fixture) == "The session file is not a regular file.")
        #expect(FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
    }

    @Test(arguments: HostShell.installed, [
        (firstLine: #"{"type":"session","version":3,"id":"019a0000-0000-7000-8000-0000000000aa","cwd":"/home/me/paper"}"#,
         expectedFailure: "The file belongs to another session. Refresh before deleting."),
        (firstLine: #"{"type":"message","id":"a1","parentId":null}"#,
         expectedFailure: "The file is not a Pi session. Refresh before deleting."),
    ])
    func aFileWhoseFirstLineIsNotThisSessionsHeaderIsRefused(
        shell: HostShell,
        headerCase: (firstLine: String, expectedFailure: String)
    ) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let companionFile = fixture.hostCompanionFolder.appendingPathComponent("forks/kept.jsonl")
        try FileManager.default.createDirectory(at: companionFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "fork".write(to: companionFile, atomically: true, encoding: .utf8)
        // The session's own header further down does not count.
        let original = try String(contentsOf: fixture.hostSessionFile, encoding: .utf8)
        try (headerCase.firstLine + "\n" + original).write(to: fixture.hostSessionFile, atomically: true, encoding: .utf8)

        #expect(deletionFailure(fixture) == headerCase.expectedFailure)
        #expect(FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
        #expect(FileManager.default.fileExists(atPath: companionFile.path))
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test(arguments: HostShell.installed)
    func aSessionHeaderNestedInsideAnotherRecordIsRefused(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let id = fixture.conversation.sessionID
        let original = try String(contentsOf: fixture.hostSessionFile, encoding: .utf8)
        try (#"{"type":"custom","data":{"type":"session","id":"\#(id)"}}"# + "\n" + original)
            .write(to: fixture.hostSessionFile, atomically: true, encoding: .utf8)

        #expect(deletionFailure(fixture) == "The file is not a Pi session. Refresh before deleting.")
        #expect(FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
    }

    @Test(arguments: HostShell.installed)
    func aSessionAlreadyGoneFromTheHostCountsAsDeletedAndDropsTheMirrorCopy(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        try FileManager.default.removeItem(at: fixture.hostSessionFile)

        try fixture.deletion().delete(fixture.conversation)

        #expect(!FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func anUnreachableHostIsReportedAsAConnectionProblem() throws {
        let fixture = try RemotePiFixture()
        defer { fixture.remove() }
        let recorder = RemoteCommandRecorder()
        let deletion = RemoteConversationDeletion(
            runner: recorder.runner(answering: (
                RemoteHostCommandRunner.connectionFailureExitStatus,
                "ssh: connect to host devbox port 22: Connection refused\n"
            )),
            mirror: fixture.mirror
        )

        let error = #expect(throws: RemoteConversationDeletionError.self) { try deletion.delete(fixture.conversation) }

        guard case .sshFailed(let host, let details) = error else {
            Issue.record("An SSH failure should be reported as one: \(String(describing: error))")
            return
        }
        #expect(host == "devbox")
        #expect(details == "ssh: connect to host devbox port 22: Connection refused")
        #expect(error?.localizedDescription == "devbox refused the SSH connection. Check that SSH is running on it.")
        #expect(recorder.commands.map(\.host) == ["devbox"])
        #expect(FileManager.default.fileExists(atPath: fixture.conversation.sourceFile.path))
    }

    @Test func passesTheNamesAsArgumentsRatherThanAsPartOfTheScript() throws {
        let fixture = try RemotePiFixture()
        defer { fixture.remove() }
        let recorder = RemoteCommandRecorder()

        try RemoteConversationDeletion(runner: recorder.runner(answering: (0, "")), mirror: fixture.mirror).delete(fixture.conversation)

        let command = try #require(recorder.commands.first?.command)
        let arguments = " sh " + [
            RemotePiFixture.projectFolderName,
            fixture.hostSessionFile.lastPathComponent,
            fixture.conversation.sessionID,
            RemoteToolFolders.standard.pi,
        ].map(ShellQuoting.quoted).joined(separator: " ")
        #expect(command.hasPrefix("sh -c '"))
        #expect(command.hasSuffix(arguments))
        #expect(!command.dropLast(arguments.count).contains(fixture.conversation.sessionID))
    }

    @Test func aSourceOutsideAProjectFolderOfThePiMirrorNeverStartsARemoteCommand() throws {
        let fixture = try RemotePiFixture()
        defer { fixture.remove() }
        let sessionID = fixture.conversation.sessionID
        let mirrorProjectFolder = fixture.conversation.sourceFile.deletingLastPathComponent()
        let mirrorDirectory = mirrorProjectFolder.deletingLastPathComponent()
        let sourceFiles = [
            mirrorDirectory.appendingPathComponent("2026-09-30T10-00-00-000Z_\(sessionID).jsonl"),
            mirrorProjectFolder.appendingPathComponent("2026-09-30T10-00-00-000Z_\(sessionID)/forks/2026-09-30T10-00-00-000Z_\(sessionID).jsonl"),
            fixture.mirror.mirrorDirectory(host: "devbox", provider: .kiro)
                .appendingPathComponent("\(RemotePiFixture.projectFolderName)/2026-09-30T10-00-00-000Z_\(sessionID).jsonl"),
            fixture.mirror.mirrorDirectory(host: "otherbox", provider: .pi)
                .appendingPathComponent("\(RemotePiFixture.projectFolderName)/2026-09-30T10-00-00-000Z_\(sessionID).jsonl"),
            mirrorProjectFolder.appendingPathComponent("2026-09-30T10-00-00-000Z_\(UUID().uuidString.lowercased()).jsonl"),
            mirrorProjectFolder.appendingPathComponent("\(sessionID).json"),
        ]
        let recorder = RemoteCommandRecorder()
        let deletion = RemoteConversationDeletion(runner: recorder.runner(answering: (0, "")), mirror: fixture.mirror)

        for sourceFile in sourceFiles {
            let conversation = Conversation.fixture(provider: .pi, sessionID: sessionID, sourceFile: sourceFile, host: .ssh("devbox"))
            #expect(throws: ConversationDeletionError.invalidSource, "\(sourceFile.path)") { try deletion.delete(conversation) }
        }

        #expect(recorder.commands.isEmpty)
        #expect(FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
    }

    /// The script checks its arguments itself too, so a session file reached through `..` or a nested folder, or
    /// named for another session, is never removed even if a caller skipped the checks in `hostFileNames`.
    @Test(arguments: HostShell.installed)
    func theScriptRefusesUnexpectedNamesWithoutRemovingAnything(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }
        let id = fixture.conversation.sessionID
        let fileName = fixture.hostSessionFile.lastPathComponent
        let agentFolder = fixture.sessionsDirectory.deletingLastPathComponent()
        let nestedFolder = fixture.sessionsDirectory.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: nestedFolder, withIntermediateDirectories: true)
        // Session files with this session's header wherever the unexpected names would lead.
        let decoys = [agentFolder.appendingPathComponent(fileName), nestedFolder.appendingPathComponent(fileName)]
        for decoy in decoys { try FileManager.default.copyItem(at: fixture.hostSessionFile, to: decoy) }
        let otherIDFileName = "2026-09-30T10-00-00-000Z_019a0000-0000-7000-8000-0000000000bb.jsonl"
        try FileManager.default.copyItem(at: fixture.hostSessionFile, to: fixture.hostProjectFolder.sessionsDirectory.appendingPathComponent(otherIDFileName))
        let cases: [(project: String, file: String, expectedOutput: String)] = [
            ("..", fileName, "Refusing an unexpected session path."),
            ("a/b", fileName, "Refusing an unexpected session path."),
            ("", fileName, "Refusing an unexpected session path."),
            (RemotePiFixture.projectFolderName, "..", "Refusing an unexpected session path."),
            (RemotePiFixture.projectFolderName, "x/" + fileName, "Refusing an unexpected session path."),
            (RemotePiFixture.projectFolderName, otherIDFileName, "The file name does not match the session."),
        ]

        for scriptCase in cases {
            let result = fixture.runOnHost(RemotePiConversationDeletion.command(
                sessionsFolder: RemoteToolFolders.standard.pi,
                projectFolderName: scriptCase.project,
                fileName: scriptCase.file,
                sessionID: id
            ))
            #expect(result?.exitStatus == 1, "\(scriptCase)")
            #expect(result?.output.trimmingCharacters(in: .whitespacesAndNewlines) == scriptCase.expectedOutput, "\(scriptCase)")
        }

        for remaining in decoys + [fixture.hostSessionFile, fixture.hostProjectFolder.sessionsDirectory.appendingPathComponent(otherIDFileName)] {
            #expect(FileManager.default.fileExists(atPath: remaining.path), "\(remaining.lastPathComponent)")
        }
    }

    @Test(arguments: HostShell.installed)
    func theScriptReportsAMissingProjectFolderAsAMissingSession(shell: HostShell) throws {
        let fixture = try RemotePiFixture(shell: shell)
        defer { fixture.remove() }

        let result = fixture.runOnHost(RemotePiConversationDeletion.command(
            sessionsFolder: RemoteToolFolders.standard.pi,
            projectFolderName: "--home-me-gone--",
            fileName: fixture.hostSessionFile.lastPathComponent,
            sessionID: fixture.conversation.sessionID
        ))

        #expect(result?.exitStatus == RemoteConversationDeletion.missingTranscriptExitStatus)
        #expect(FileManager.default.fileExists(atPath: fixture.hostSessionFile.path))
    }

    /// The details of the failure the host reported; the deletion must fail without removing anything.
    private func deletionFailure(_ fixture: RemotePiFixture) -> String? {
        let error = #expect(throws: RemoteConversationDeletionError.self) { try fixture.deletion().delete(fixture.conversation) }
        guard case .failed(let host, let details) = error else {
            Issue.record("Expected the host to refuse the deletion: \(String(describing: error))")
            return nil
        }
        #expect(host == "devbox")
        return details
    }
}
