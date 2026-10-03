import Foundation

/// The SQL that builds an SSH host's OpenCode mirror from its database, attached as `source`: the sessions JustSessions
/// lists and what their previews read, and nothing else. OpenCode's accounts, credentials, and event log stay on the
/// host, and so do tool outputs, attachments, and subagent sessions. The same steps run on the host, in python3,
/// and in the tests, so both build the same mirror.
enum OpenCodeMirrorSnapshotSteps {
    /// Each step is a list of statements tried in order until one succeeds: a database from before OpenCode recorded
    /// archiving still lists, and a host whose SQLite lacks JSON functions copies messages and parts whole.
    static let steps: [[String]] = [
        ["""
            CREATE TABLE session (id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT, time_created INTEGER,
                time_updated INTEGER, time_archived INTEGER, revert TEXT)
            """],
        ["CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT)"],
        ["""
            CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER,
                time_updated INTEGER, data TEXT)
            """],
        [
            """
            INSERT INTO session SELECT id, parent_id, directory, title, time_created, time_updated, time_archived, revert
            FROM source.session WHERE parent_id IS NULL AND time_archived IS NULL
            """,
            """
            INSERT INTO session (id, parent_id, directory, title, time_updated)
            SELECT id, parent_id, directory, title, time_updated FROM source.session WHERE parent_id IS NULL
            """,
        ],
        [
            """
            INSERT INTO message SELECT id, session_id, time_created, time_updated, \(OpenCodeTranscriptMessage.dataProjection)
            FROM source.message WHERE session_id IN (SELECT id FROM session)
            """,
            """
            INSERT INTO message SELECT id, session_id, time_created, time_updated, data
            FROM source.message WHERE session_id IN (SELECT id FROM session)
            """,
        ],
        [
            """
            INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, \(OpenCodeTranscriptParts.dataProjection)
            FROM source.part WHERE session_id IN (SELECT id FROM session) AND \(OpenCodeTranscriptParts.typeFilter)
            """,
            """
            INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, data
            FROM source.part WHERE session_id IN (SELECT id FROM session)
            """,
        ],
        ["CREATE INDEX message_session_time_created_id_idx ON message (session_id, time_created, id)"],
        ["CREATE INDEX part_message_id_id_idx ON part (message_id, id)"],
    ]

    /// `steps` as a JSON array, which is also a Python list literal.
    static var json: String {
        let data = (try? JSONSerialization.data(withJSONObject: steps, options: [.withoutEscapingSlashes])) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }
}
