import Foundation

/// A Pi sessions folder: one subfolder per project, holding `<timestamp>_<session id>.jsonl` files.
struct PiSessionFolderFixture {
    let sessionsDirectory: URL

    /// Writes a session file whose first line is Pi's session header, followed by `lines`.
    @discardableResult
    func writeSession(
        id sessionID: String,
        projectPath: String,
        lines: [String] = [],
        fileSessionID: String? = nil,
        inProjectFolder: Bool = true
    ) throws -> URL {
        let folder = inProjectFolder
            ? sessionsDirectory.appendingPathComponent("--" + projectPath.dropFirst().replacingOccurrences(of: "/", with: "-") + "--")
            : sessionsDirectory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appendingPathComponent("2026-09-30T10-00-00-000Z_\(fileSessionID ?? sessionID).jsonl")
        let header = #"{"type":"session","version":3,"id":"\#(sessionID)","timestamp":"2026-09-30T10:00:00.000Z","cwd":"\#(projectPath)"}"#
        try ([header] + lines).map { $0 + "\n" }.joined().write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Writes a subagent's session file at `relativePath` in the folder beside `sessionFile`, as Pi extensions keep
    /// them. A fork's header names the file of the session it came from.
    @discardableResult
    func writeSubagentSession(
        id sessionID: String,
        at relativePath: String,
        inFolderOf sessionFile: URL,
        projectPath: String = "/Users/me/app",
        forkedFrom parentFile: URL? = nil,
        lines: [String] = []
    ) throws -> URL {
        let file = sessionFile.deletingPathExtension().appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let parentSession = parentFile.map { #","parentSession":"\#($0.path)""# } ?? ""
        let header = #"{"type":"session","version":3,"id":"\#(sessionID)","timestamp":"2026-09-30T10:05:00.000Z","cwd":"\#(projectPath)"\#(parentSession)}"#
        try ([header] + lines).map { $0 + "\n" }.joined().write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    static func userMessage(_ text: String) -> String {
        #"{"type":"message","id":"a1","parentId":null,"timestamp":"2026-09-30T10:00:01.000Z","message":{"role":"user","content":[{"type":"text","text":"\#(text)"}]}}"#
    }

    static func sessionName(_ name: String) -> String {
        #"{"type":"session_info","id":"b1","parentId":"a1","timestamp":"2026-09-30T10:00:02.000Z","name":"\#(name)"}"#
    }
}
