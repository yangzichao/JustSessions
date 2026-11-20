import Foundation

@testable import JustSessions

/// What Claude Code 2.1.306 wrote for `/branch` typed in a running CLI, then `/rename after-branch`, trimmed to the
/// lines and fields that matter. The CLI stays the same process and moves itself into the branch: the registry names
/// the branch from then on, and the session it branched from gets nothing more. The branch's file copies the messages
/// with their uuids and timestamps, its own `sessionId`, and `forkedFrom` naming the session it branched from; the
/// title `/branch` gives it comes after them, and `/rename` appends another. The test calls `remove()`.
struct ClaudeBranchCommandTranscripts {
    static let parentID = "4f80d7f2-88b3-4d73-8423-34f5faa8e081"
    static let branchID = "1fe21c86-d52a-4ee8-895f-155bf341fbb6"
    static let processID: Int32 = 5823
    static let parentPrompt = "Reply with the single word OK."
    /// The title Claude Code generated for the session branched from, which names it: it has no name of its own.
    static let parentTitle = "Single word OK reply"
    static let branchTitle = "Reply with the single word OK. (Branch)"
    private static let relayTranscriptTailByteCount = 65_536

    enum Step {
        case beforeBranch, branched, renamed

        var record: String {
            switch self {
            case .beforeBranch:
                #"{"pid":5823,"sessionId":"\#(parentID)","kind":"interactive","entrypoint":"cli","name":"project-1c","nameSource":"derived","status":"idle"}"#
            case .branched:
                #"{"pid":5823,"sessionId":"\#(branchID)","kind":"interactive","entrypoint":"cli","name":"\#(branchTitle)","nameSource":"user","status":"idle"}"#
            case .renamed:
                #"{"pid":5823,"sessionId":"\#(branchID)","kind":"interactive","entrypoint":"cli","name":"after-branch","nameSource":"user","status":"idle","formerNames":[{"name":"\#(branchTitle)","sessionId":"\#(branchID)"}]}"#
            }
        }

        var sessionID: String { self == .beforeBranch ? parentID : branchID }
    }

    let root: URL
    let configurationDirectory: URL
    let projectDirectory: URL

    init() throws {
        root = try makeTemporaryDirectory()
        configurationDirectory = root.appendingPathComponent(".claude")
        projectDirectory = configurationDirectory.appendingPathComponent("projects/-Users-me-project")
        try FileManager.default.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: configurationDirectory.appendingPathComponent("sessions"),
            withIntermediateDirectories: true
        )
        try append(
            to: Self.parentID,
            [
                #"{"type":"permission-mode","permissionMode":"auto","sessionId":"\#(Self.parentID)"}"#,
                Self.prompt(sessionID: Self.parentID, forked: false),
                #"{"type":"ai-title","aiTitle":"\#(Self.parentTitle)","sessionId":"\#(Self.parentID)"}"#,
                Self.reply(sessionID: Self.parentID, forked: false),
                #"{"type":"last-prompt","leafUuid":"77841e5c-1174-4c06-9485-052950c03f48","sessionId":"\#(Self.parentID)"}"#,
            ])
        try writeRecord(.beforeBranch)
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    func file(of sessionID: String) -> URL {
        projectDirectory.appendingPathComponent("\(sessionID).jsonl")
    }

    /// `/branch`: the branch's file is written in full before the registry names it.
    func branch() throws {
        try append(
            to: Self.branchID,
            [
                Self.prompt(sessionID: Self.branchID, forked: true),
                Self.reply(sessionID: Self.branchID, forked: true),
                #"{"type":"atis-latch","sessionId":"\#(Self.branchID)"}"#,
                Self.customTitleLine(Self.branchTitle),
                #"{"type":"agent-name","agentName":"\#(Self.branchTitle)","sessionId":"\#(Self.branchID)"}"#,
            ])
        try append(to: Self.parentID, [#"{"type":"cost-state","sessionId":"\#(Self.parentID)"}"#])
        try writeRecord(.branched)
    }

    func rename() throws {
        try append(
            to: Self.branchID,
            [
                Self.customTitleLine("after-branch"),
                #"{"type":"agent-name","agentName":"after-branch","sessionId":"\#(Self.branchID)"}"#,
            ])
        try writeRecord(.renamed)
    }

    func listed(on host: SessionHost = .thisMac) throws -> [Conversation] {
        try ClaudeAdapter(configurationDirectory: configurationDirectory).discover().map { $0.onHost(host) }
    }

    func relayTitle(at step: Step) throws -> String {
        let transcriptTheRelayReads = try Data(contentsOf: file(of: step.sessionID)).suffix(Self.relayTranscriptTailByteCount)
        let transcript = String(decoding: transcriptTheRelayReads, as: UTF8.self)
        let titleLine = transcript.split(separator: "\n").last { $0.contains(#""type":"custom-title""#) }.map(String.init) ?? ""
        return RemoteClaudeSessionTitle.titlePrefix + Data(step.record.utf8).base64EncodedString() + ":"
            + Data(titleLine.utf8).base64EncodedString()
    }

    func writeRecord(_ record: String) throws {
        try Data(record.utf8).write(to: configurationDirectory.appendingPathComponent("sessions/\(Self.processID).json"))
    }

    private func writeRecord(_ step: Step) throws {
        try writeRecord(step.record)
    }

    func append(to sessionID: String, _ lines: [String]) throws {
        let file = file(of: sessionID)
        if !FileManager.default.fileExists(atPath: file.path) { try Data().write(to: file) }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(lines.map { $0 + "\n" }.joined().utf8))
    }

    private static func customTitleLine(_ title: String) -> String {
        #"{"type":"custom-title","customTitle":"\#(title)","sessionId":"\#(branchID)"}"#
    }

    private static func prompt(sessionID: String, forked: Bool) -> String {
        let uuid = "a26341e3-5e47-49e8-bd48-511852da9c22"
        return
            #"{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"\#(parentPrompt)"},"uuid":"\#(uuid)","timestamp":"2026-10-21T19:45:31.357Z","cwd":"/Users/me/project","sessionId":"\#(sessionID)","version":"2.1.306"\#(forkedFrom(uuid, forked))}"#
    }

    /// A copied reply keeps the snake_case `session_id` of the session it came from.
    private static func reply(sessionID: String, forked: Bool) -> String {
        let uuid = "77841e5c-1174-4c06-9485-052950c03f48"
        return
            #"{"parentUuid":"a26341e3-5e47-49e8-bd48-511852da9c22","isSidechain":false,"message":{"model":"claude-opus-5-5","type":"message","role":"assistant","content":[{"type":"text","text":"OK"}]},"type":"assistant","uuid":"\#(uuid)","timestamp":"2026-10-21T19:45:33.854Z","session_id":"\#(parentID)","cwd":"/Users/me/project","sessionId":"\#(sessionID)","version":"2.1.306"\#(forkedFrom(uuid, forked))}"#
    }

    private static func forkedFrom(_ uuid: String, _ forked: Bool) -> String {
        forked ? #","forkedFrom":{"sessionId":"\#(parentID)","messageUuid":"\#(uuid)"}"# : ""
    }
}
