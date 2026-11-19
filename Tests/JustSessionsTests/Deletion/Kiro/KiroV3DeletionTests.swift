import Foundation
import Testing

@testable import JustSessions

/// Deleting a Kiro CLI V3 session runs `kiro-cli chat --delete-session <sess_ id>`, which removes its folder (Kiro CLI
/// 2.16.2), with the same checks as a V2 session's.
struct KiroV3DeletionTests {
    private struct Home {
        let root: URL
        let kiroDirectory: URL
        let projectDirectory: URL
        var sessionsRoot: URL { kiroDirectory.appendingPathComponent("sessions") }
        var classicDirectory: URL { sessionsRoot.appendingPathComponent("cli") }

        init() throws {
            root = try makeTemporaryDirectory()
            kiroDirectory = root.appendingPathComponent("custom kiro home; $dollar")
            projectDirectory = root.appendingPathComponent("project with spaces")
            try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: classicDirectory, withIntermediateDirectories: true)
        }

        func adapter(running script: String) throws -> KiroAdapter {
            KiroAdapter(
                sessionsDirectory: classicDirectory, v3SessionsDirectory: sessionsRoot,
                deletionExecutableURL: try writeExecutableScript(script, to: root.appendingPathComponent("kiro-cli")))
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }

    /// Deletes the folder named for its session in any workspace, as Kiro does.
    static let successfulDeletionScript = """
        #!/bin/sh
        [ "$1" = chat ] && [ "$2" = --delete-session ] && [ "$#" -eq 3 ] || exit 9
        /bin/rm -rf "$KIRO_HOME"/sessions/*/"$3"
        """

    @Test func deletesOnlyTheSelectedSessionInItsProjectAndKiroHome() throws {
        let home = try Home()
        defer { home.remove() }
        let fixture = KiroV3SessionFixture(sessionsRoot: home.sessionsRoot)
        let selected = try fixture.writeSession(projectPath: home.projectDirectory.path)
        let kept = try fixture.writeSession(projectPath: home.projectDirectory.path)
        let reportFile = home.root.appendingPathComponent("report.txt")
        let adapter = try home.adapter(
            running: Self.successfulDeletionScript + "\n"
                + "printf '%s\\n' \"$@\" \"$KIRO_HOME\" \"$PWD\" > \(ShellQuoting.quoted(reportFile.path))\n")
        let conversation = try #require(adapter.discover().first { $0.sessionID == selected.sessionID })

        try adapter.delete(conversation)

        let report = try String(contentsOf: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(report.prefix(4)) == ["chat", "--delete-session", selected.sessionID, home.kiroDirectory.path])
        #expect(
            URL(fileURLWithPath: try #require(report.last)).resolvingSymlinksInPath().path
                == home.projectDirectory.resolvingSymlinksInPath().path)
        #expect(!FileManager.default.fileExists(atPath: selected.folder.path))
        #expect(try adapter.discover().map(\.sessionID) == [kept.sessionID])
    }

    @Test func aCLIThatLeavesTheFolderReportsIt() throws {
        let home = try Home()
        defer { home.remove() }
        let selected = try KiroV3SessionFixture(sessionsRoot: home.sessionsRoot).writeSession(projectPath: home.projectDirectory.path)
        let adapter = try home.adapter(running: "#!/bin/sh\nexit 0\n")
        let conversation = try #require(adapter.discover().first)

        #expect(throws: KiroConversationDeletionError.sourceStillPresent) { try adapter.delete(conversation) }
        #expect(FileManager.default.fileExists(atPath: selected.messagesFile.path))
    }

    /// A session whose file isn't where its folder says, or whose metadata names another session or folder, isn't
    /// handed to Kiro.
    @Test func aSessionOutsideItsWorkspaceFolderOrNamingAnotherIsRefused() throws {
        let home = try Home()
        defer { home.remove() }
        let fixture = KiroV3SessionFixture(sessionsRoot: home.sessionsRoot)
        let written = try fixture.writeSession(projectPath: home.projectDirectory.path)
        let reportFile = home.root.appendingPathComponent("ran.txt")
        let adapter = try home.adapter(running: "#!/bin/sh\ntouch \(ShellQuoting.quoted(reportFile.path))\n")
        let listed = try #require(adapter.discover().first)
        let candidates = [
            Conversation.fixture(
                provider: .kiro, sessionID: listed.sessionID, projectPath: "/Users/me/elsewhere", sourceFile: listed.sourceFile),
            Conversation.fixture(
                provider: .kiro, sessionID: "sess_" + UUID().uuidString.lowercased(),
                projectPath: listed.projectPath, sourceFile: listed.sourceFile),
            Conversation.fixture(
                provider: .kiro, sessionID: listed.sessionID, projectPath: listed.projectPath,
                sourceFile: home.classicDirectory.appendingPathComponent(listed.sessionID)
                    .appendingPathComponent(KiroV3Session.messagesFileName)),
            Conversation.fixture(
                provider: .kiro, sessionID: listed.sessionID, projectPath: listed.projectPath,
                sourceFile: home.root.appendingPathComponent("a/\(listed.sessionID)/messages.jsonl")),
        ]

        for candidate in candidates {
            #expect(throws: (any Error).self) { try adapter.delete(candidate) }
        }
        #expect(!FileManager.default.fileExists(atPath: reportFile.path))
        #expect(FileManager.default.fileExists(atPath: written.messagesFile.path))
    }

    /// Kiro CLI 2.34.0 deletes a V3 session a running CLI holds, whose next turn writes its folder again.
    @Test func aSessionARunningCLIHoldsIsNotHandedToKiro() throws {
        let home = try Home()
        defer { home.remove() }
        let selected = try KiroV3SessionFixture(sessionsRoot: home.sessionsRoot).writeSession(projectPath: home.projectDirectory.path)
        try KiroSessionLockTests.writeLock(
            processID: getpid(), startedAt: .now, fractionalDigits: 3,
            to: selected.folder.appendingPathComponent(".lock"))
        let adapter = try home.adapter(running: Self.successfulDeletionScript)
        let conversation = try #require(adapter.discover().first)

        #expect(throws: KiroConversationDeletionError.stillRunning) { try adapter.delete(conversation) }
        #expect(FileManager.default.fileExists(atPath: selected.messagesFile.path))
    }

    /// The prompts Kiro keeps for a V3 session sit in `sessions/cli`, named for its `sess_` id.
    @Test func thePromptsKiroLeavesInTheClassicFolderGoWithTheSession() throws {
        let home = try Home()
        defer { home.remove() }
        let selected = try KiroV3SessionFixture(sessionsRoot: home.sessionsRoot).writeSession(projectPath: home.projectDirectory.path)
        let history = home.classicDirectory.appendingPathComponent("\(selected.sessionID).history")
        try "Reply with exactly LOCK.\n".write(to: history, atomically: true, encoding: .utf8)
        let adapter = try home.adapter(running: Self.successfulDeletionScript)

        try adapter.delete(try #require(adapter.discover().first))

        #expect(!FileManager.default.fileExists(atPath: selected.folder.path))
        #expect(!FileManager.default.fileExists(atPath: history.path))
    }
}
