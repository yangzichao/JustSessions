import Foundation
import SQLite3

struct AntigravityLocalSession {
    let sessionID: String
    let projectPath: String
    let firstPrompt: String?
}

struct AntigravityConversationSummary {
    let title: String?
    let preview: String?
    let projectPath: String?
    let updatedAt: Date?
}

enum AntigravitySQLiteReader {
    static func localSession(at file: URL) -> AntigravityLocalSession? {
        guard let database = openReadOnly(file) else { return nil }
        defer { sqlite3_close(database) }

        guard let sessionID = firstText(in: database, query: "SELECT cascade_id FROM trajectory_meta LIMIT 1"),
              let metadata = firstBlob(in: database, query: "SELECT data FROM trajectory_metadata_blob LIMIT 1"),
              let workspaceURI = AntigravityProtobuf.text(in: metadata, at: [1, 1]),
              let projectURL = URL(string: workspaceURI), projectURL.isFileURL else { return nil }

        let firstStep = firstBlob(
            in: database,
            query: "SELECT step_payload FROM steps WHERE step_type = 14 ORDER BY idx LIMIT 1"
        )
        let firstPrompt = firstStep.flatMap { AntigravityProtobuf.text(in: $0, at: [19, 2]) }
        return AntigravityLocalSession(
            sessionID: sessionID,
            projectPath: projectURL.standardizedFileURL.path,
            firstPrompt: firstPrompt
        )
    }

    static func summaries(at file: URL) -> [String: AntigravityConversationSummary] {
        guard let database = openReadOnly(file) else { return [:] }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        let query = """
            SELECT conversation_id, title, preview, workspace_uris, last_modified_time
            FROM conversation_summaries WHERE app_data_dir = 'antigravity-cli'
            """
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else { return [:] }
        defer { sqlite3_finalize(statement) }

        var summaries: [String: AntigravityConversationSummary] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let sessionID = textColumn(statement, at: 0) else { continue }
            let workspaceJSON = textColumn(statement, at: 3) ?? "[]"
            let workspaceURIs = (try? JSONSerialization.jsonObject(with: Data(workspaceJSON.utf8))) as? [String]
            let projectPath = workspaceURIs?.compactMap { uri -> String? in
                guard let url = URL(string: uri), url.isFileURL else { return nil }
                return url.standardizedFileURL.path
            }.first
            let timestamp = textColumn(statement, at: 4)?.replacingOccurrences(of: " ", with: "T")
            summaries[sessionID] = AntigravityConversationSummary(
                title: textColumn(statement, at: 1),
                preview: textColumn(statement, at: 2),
                projectPath: projectPath,
                updatedAt: ConversationMetadata.date(timestamp)
            )
        }
        return summaries
    }

    private static func openReadOnly(_ file: URL) -> OpaquePointer? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        var database: OpaquePointer?
        guard sqlite3_open_v2(file.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let database { sqlite3_close(database) }
            return nil
        }
        return database
    }

    private static func firstText(in database: OpaquePointer, query: String) -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return textColumn(statement, at: 0)
    }

    private static func firstBlob(in database: OpaquePointer, query: String) -> Data? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              let bytes = sqlite3_column_blob(statement, 0) else { return nil }
        return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
    }

    private static func textColumn(_ statement: OpaquePointer?, at index: Int32) -> String? {
        guard let bytes = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: UnsafeRawPointer(bytes).assumingMemoryBound(to: CChar.self))
    }
}
