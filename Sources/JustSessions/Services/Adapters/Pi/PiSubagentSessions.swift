import Foundation

struct PiSubagentSession: Sendable, Codable {
    let sessionID: String
    let projectPath: String
    let title: String

    init?(file: URL) {
        guard let header = ConversationMetadata.firstLine(of: file),
            header["type"] as? String == "session",
            let sessionID = header["id"] as? String,
            ConversationMetadata.isValidSessionID(sessionID),
            let projectPath = header["cwd"] as? String, projectPath.hasPrefix("/")
        else { return nil }
        self.sessionID = sessionID
        self.projectPath = projectPath
        // A fork opens with the history of the session it came from, so its own task is its latest prompt.
        title = ConversationMetadata.cleanTitle(
            header["parentSession"] != nil ? PiSessionTitle.latestUserPrompt(in: file) : PiSessionTitle.firstUserPrompt(in: file),
            fallback: ConversationMetadata.untitledConversationTitle
        )
    }
}

/// Pi extensions that run subagents keep each one's session in the folder named after the file of the session that
/// started it, such as `<timestamp>_<id>/<run id>/run-0/session.jsonl` or `<timestamp>_<id>/forks/<timestamp>_<id>.jsonl`.
/// A subagent's own subagents are in the folder named after its file in turn.
enum PiSubagentSessions {
    struct Found {
        let file: URL
        let session: PiSubagentSession
        let parentSessionID: String
    }

    private static let folderDepthNoExtensionReaches = 12

    static func find(startedBy sessionFile: URL, sessionID: String, read: (URL) -> PiSubagentSession?) -> [Found] {
        var found: [Found] = []
        collect(in: sessionFile.deletingPathExtension(), parentSessionID: sessionID, depth: 0, read: read, into: &found)
        return found
    }

    private static func collect(
        in folder: URL,
        parentSessionID: String,
        depth: Int,
        read: (URL) -> PiSubagentSession?,
        into found: inout [Found]
    ) {
        guard depth < folderDepthNoExtensionReaches,
            let entries = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .contentModificationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )
        else { return }
        var sessionIDsByFolderName: [String: String] = [:]
        for file in entries where file.pathExtension == "jsonl" && file.isPlainFileNotLinkOrPipe {
            guard let session = read(file) else { continue }
            found.append(Found(file: file, session: session, parentSessionID: parentSessionID))
            sessionIDsByFolderName[file.deletingPathExtension().lastPathComponent] = session.sessionID
        }
        for entry in entries where isDirectory(entry) {
            collect(
                in: entry,
                parentSessionID: sessionIDsByFolderName[entry.lastPathComponent] ?? parentSessionID,
                depth: depth + 1,
                read: read,
                into: &found
            )
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        return values?.isDirectory == true && values?.isSymbolicLink != true
    }
}
