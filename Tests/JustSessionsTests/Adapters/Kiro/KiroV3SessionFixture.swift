import CryptoKit
import Foundation

@testable import JustSessions

/// Kiro CLI V3's `sessions` folder: `<workspace hash>/sess_<uuid>/session.json` beside `messages.jsonl`, with the fields
/// and events Kiro CLI 2.16.2's and 2.34.0's V3 engines wrote on this Mac on 23 October 2026 (`KiroV3Session`).
struct KiroV3SessionFixture {
    /// Kiro's `sessions`, which also holds V2's `cli`.
    let sessionsRoot: URL

    struct Written {
        let sessionID: String
        let folder: URL
        var messagesFile: URL { folder.appendingPathComponent(KiroV3Session.messagesFileName) }
        var metadataFile: URL { folder.appendingPathComponent(KiroV3Session.metadataFileName) }
    }

    /// The first 16 hex digits of the SHA-256 of the folder, as Kiro names a workspace's folder.
    static func workspaceHash(of projectPath: String) -> String {
        SHA256.hash(data: Data(projectPath.utf8)).map { String(format: "%02x", $0) }.joined().prefix(16).description
    }

    @discardableResult
    func writeSession(
        sessionID: String = "sess_" + UUID().uuidString.lowercased(),
        projectPath: String,
        title: String? = "Fix the build",
        createdReason: String? = nil,
        lastModifiedAt: String = "2026-10-23T23:23:08.579Z",
        events: [[String: Any]]? = Self.sampleEvents,
        extraFiles: [String: String] = [:]
    ) throws -> Written {
        let folder = sessionsRoot.appendingPathComponent(Self.workspaceHash(of: projectPath)).appendingPathComponent(sessionID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var metadata: [String: Any] = [
            "schemaVersion": "1.0.0", "dataModelVersion": 1, "id": sessionID, "agentMode": "vibe",
            "workspacePaths": [projectPath], "createdAt": "2026-10-23T23:23:04.664Z", "lastModifiedAt": lastModifiedAt,
            "modelId": "auto", "status": "idle",
        ]
        if let title { metadata["title"] = title }
        if let createdReason { metadata["createdReason"] = createdReason }
        try JSONSerialization.data(withJSONObject: metadata).write(to: folder.appendingPathComponent(KiroV3Session.metadataFileName))
        if let events {
            try Self.lines(events).write(
                to: folder.appendingPathComponent(KiroV3Session.messagesFileName), atomically: true, encoding: .utf8)
        }
        for (name, contents) in extraFiles {
            let file = folder.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try contents.write(to: file, atomically: true, encoding: .utf8)
        }
        return Written(sessionID: sessionID, folder: folder)
    }

    /// One line per event; none for none, as an empty file.
    static func lines(_ events: [[String: Any]]) throws -> String {
        guard !events.isEmpty else { return "" }
        return try events.enumerated().map { index, payload in
            let event: [String: Any] = ["id": "event-\(index)", "timestamp": "2026-10-23T23:23:0\(min(index, 9)).000Z", "payload": payload]
            return String(decoding: try JSONSerialization.data(withJSONObject: event), as: UTF8.self)
        }.joined(separator: "\n") + "\n"
    }

    static func user(_ text: String, images: Int = 0) -> [String: Any] {
        [
            "type": "user", "content": text, "images": Array(repeating: ["mimeType": "image/png"], count: images), "documents": [],
            "_meta": ["kiro": ["userMessageTag": "prompt_1"]],
        ]
    }

    static func say(_ text: String) -> [String: Any] {
        ["type": "assistant", "content": text, "operationType": "Say", "executionId": "exec-1"]
    }

    static func reasoning(_ text: String) -> [String: Any] {
        ["type": "assistant", "content": text, "operationType": "Reasoning", "executionId": "exec-1", "reasoningSignature": "sig"]
    }

    /// As Kiro wrote a shell command it then asked to run; `status` was `denied` because the probe ran without approval.
    static var toolCall: [String: Any] {
        [
            "type": "tool_call", "toolCallId": "run_command_1", "toolName": "execute_bash",
            "args": ["command": "swift build", "run_in_background": false], "status": "completed", "kind": "execute",
            "executionId": "exec-1", "actionType": "run_command", "title": "Run Command",
        ]
    }

    static var sampleEvents: [[String: Any]] {
        [
            // 2.34.0 opens each log with context for the model.
            ["type": "agent_note", "content": "<session_context>\nThe current model is Auto.\n</session_context>"],
            user("Fix the build"),
            ["type": "turn_start", "executionId": "exec-1"],
            ["type": "pending_interaction", "interactionType": "tool_approval", "toolCallId": "run_command_1", "question": "swift build"],
            ["type": "interaction_resolved", "toolCallId": "run_command_1", "outcome": "accepted"],
            toolCall,
            ["type": "tool_result", "toolCallId": "run_command_1", "content": "Build complete!", "success": true, "executionId": "exec-1"],
            reasoning("The build passes now."),
            ["type": "session_metadata", "key": "contextUsage", "value": ["usagePercentage": 2.6]],
            say("The build passes."),
            ["type": "usage_summary", "promptTurnSummaries": [], "status": "success", "executionId": "exec-1"],
            ["type": "turn_end", "stopReason": "end_turn", "executionId": "exec-1"],
            ["type": "session_start", "agentType": "vibe", "content": "You are Kiro, the system prompt.", "forcedRole": true],
        ]
    }
}
