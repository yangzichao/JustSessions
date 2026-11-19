import Foundation

struct OpenCodeMirrorSnapshotStep: Encodable, Equatable {
    let statement: String
    let fallbackWhenSomethingIsMissing: String?

    init(_ statement: String, fallbackWhenSomethingIsMissing: String? = nil) {
        self.statement = statement
        self.fallbackWhenSomethingIsMissing = fallbackWhenSomethingIsMissing
    }
}

enum OpenCodeMirrorSnapshotSteps {
    /// A database from before OpenCode recorded archiving still lists, and a host whose SQLite lacks JSON functions
    /// copies messages and parts whole.
    static let steps: [OpenCodeMirrorSnapshotStep] = [
        OpenCodeMirrorSnapshotStep(
            """
            CREATE TABLE session (id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT, time_created INTEGER,
                time_updated INTEGER, time_archived INTEGER, revert TEXT)
            """
        ),
        OpenCodeMirrorSnapshotStep(
            "CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT)"),
        OpenCodeMirrorSnapshotStep(
            """
            CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER,
                time_updated INTEGER, data TEXT)
            """
        ),
        OpenCodeMirrorSnapshotStep(
            """
            INSERT INTO session SELECT id, parent_id, directory, title, time_created, time_updated, time_archived, revert
            FROM source.session WHERE parent_id IS NULL AND time_archived IS NULL
            """,
            fallbackWhenSomethingIsMissing: """
                INSERT INTO session (id, parent_id, directory, title, time_updated)
                SELECT id, parent_id, directory, title, time_updated FROM source.session WHERE parent_id IS NULL
                """
        ),
        OpenCodeMirrorSnapshotStep(
            """
            INSERT INTO message SELECT id, session_id, time_created, time_updated, \(OpenCodeTranscriptMessage.dataProjection)
            FROM source.message WHERE session_id IN (SELECT id FROM session)
            """,
            fallbackWhenSomethingIsMissing: """
                INSERT INTO message SELECT id, session_id, time_created, time_updated, data
                FROM source.message WHERE session_id IN (SELECT id FROM session)
                """
        ),
        OpenCodeMirrorSnapshotStep(
            """
            INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, \(OpenCodeTranscriptParts.dataProjection)
            FROM source.part WHERE session_id IN (SELECT id FROM session) AND \(OpenCodeTranscriptParts.typeFilter)
            """,
            fallbackWhenSomethingIsMissing: """
                INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, data
                FROM source.part WHERE session_id IN (SELECT id FROM session)
                """
        ),
        OpenCodeMirrorSnapshotStep("CREATE INDEX message_session_time_created_id_idx ON message (session_id, time_created, id)"),
        OpenCodeMirrorSnapshotStep("CREATE INDEX part_message_id_id_idx ON part (message_id, id)"),
    ]

    /// `steps` as a JSON array of objects, which is also a Python list of dicts; a step without a fallback leaves the
    /// key out, as JSON's `null` is not Python.
    static var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes, .sortedKeys]
        let data = (try? encoder.encode(steps)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
