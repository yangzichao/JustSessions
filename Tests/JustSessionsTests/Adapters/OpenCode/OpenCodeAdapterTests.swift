import Foundation
import SQLite3
import Testing
@testable import JustSessions

struct OpenCodeAdapterTests {
    @Test func listsTopLevelSessionsThatAreNotArchived() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let databaseFile = root.appendingPathComponent("opencode.db")
        try execute([
            """
            CREATE TABLE session (id TEXT PRIMARY KEY, project_id TEXT, parent_id TEXT, directory TEXT, title TEXT,
                time_created INTEGER, time_updated INTEGER, time_archived INTEGER)
            """,
            "INSERT INTO session VALUES ('ses_titled0001', 'p', NULL, '/Users/me/app', 'Fix login', 1, 1790000000500, NULL)",
            "INSERT INTO session VALUES ('ses_untitled01', 'p', NULL, '/Users/me/app', 'New session - 2026-09-30T10:00:00.000Z', 1, 1790000000000, NULL)",
            "INSERT INTO session VALUES ('ses_subagent01', 'p', 'ses_titled0001', '/Users/me/app', 'Subtask', 1, 1, NULL)",
            "INSERT INTO session VALUES ('ses_archived01', 'p', NULL, '/Users/me/app', 'Archived', 1, 1, 1790000000000)",
            "INSERT INTO session VALUES ('not-an-opencode-id', 'p', NULL, '/Users/me/app', 'Odd', 1, 1, NULL)",
            "INSERT INTO session VALUES ('ses_relative01', 'p', NULL, 'relative/app', 'Odd', 1, 1, NULL)",
        ], at: databaseFile)

        let found = try OpenCodeAdapter(databaseFile: databaseFile).discover()

        #expect(Set(found.map(\.sessionID)) == ["ses_titled0001", "ses_untitled01"])
        let titled = try #require(found.first { $0.sessionID == "ses_titled0001" })
        #expect(titled.provider == .opencode)
        #expect(titled.projectPath == "/Users/me/app")
        #expect(titled.suggestedTitle == "Fix login")
        #expect(titled.updatedAt == Date(timeIntervalSince1970: 1_790_000_000.5))
        #expect(titled.sourceFile == databaseFile)
        #expect(found.first { $0.sessionID == "ses_untitled01" }?.suggestedTitle == ConversationMetadata.untitledConversationTitle)
    }

    @Test func databaseWithoutArchivingStillLists() throws {
        let root = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let databaseFile = root.appendingPathComponent("opencode.db")
        try execute([
            "CREATE TABLE session (id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT, time_updated INTEGER)",
            "INSERT INTO session VALUES ('ses_olderschema', NULL, '/Users/me/app', 'Older', 1790000000000)",
        ], at: databaseFile)

        #expect(try OpenCodeAdapter(databaseFile: databaseFile).discover().map(\.sessionID) == ["ses_olderschema"])
        #expect(try OpenCodeAdapter(databaseFile: root.appendingPathComponent("missing.db")).discover().isEmpty)
    }

    @Test func databaseLocationFollowsOpenCodesEnvironment() {
        #expect(OpenCodeAdapter.standardDatabaseFile(environment: [:], homeDirectory: "/Users/me").path
            == "/Users/me/.local/share/opencode/opencode.db")
        #expect(OpenCodeAdapter.standardDatabaseFile(environment: ["XDG_DATA_HOME": "/data"], homeDirectory: "/Users/me").path
            == "/data/opencode/opencode.db")
        #expect(OpenCodeAdapter.standardDatabaseFile(environment: ["OPENCODE_DB": "/tmp/oc.db"], homeDirectory: "/Users/me").path
            == "/tmp/oc.db")
        #expect(OpenCodeAdapter.standardDatabaseFile(environment: ["OPENCODE_DB": "oc.db"], homeDirectory: "/Users/me").path
            == "/Users/me/.local/share/opencode/opencode.db")
    }

    @Test func onlyADatedNewSessionTitleIsAPlaceholder() {
        #expect(OpenCodeAdapter.isPlaceholderTitle("New session - 2026-09-30T10:00:00.000Z"))
        #expect(!OpenCodeAdapter.isPlaceholderTitle("New session - notes"))
        #expect(!OpenCodeAdapter.isPlaceholderTitle("Fix login"))
    }

    @Test func sessionIDsMustLookLikeOpenCodes() {
        #expect(ConversationProvider.opencode.isValidSessionID("ses_3a9f0c2be1ffe9TNd6Ab7kQ2xM"))
        #expect(!ConversationProvider.opencode.isValidSessionID("ses_short"))
        #expect(!ConversationProvider.opencode.isValidSessionID("ses_abc; rm -rf ~"))
        #expect(!ConversationProvider.opencode.isValidSessionID(UUID().uuidString))
        #expect(!ConversationProvider.claude.isValidSessionID("ses_3a9f0c2be1ffe9TNd6Ab7kQ2xM"))
    }

    private func execute(_ statements: [String], at file: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(file.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "OpenCodeAdapterTests", code: 1)
        }
        defer { sqlite3_close(database) }
        for statement in statements {
            guard sqlite3_exec(database, statement, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "OpenCodeAdapterTests", code: 2, userInfo: [NSLocalizedDescriptionKey: statement])
            }
        }
    }
}
