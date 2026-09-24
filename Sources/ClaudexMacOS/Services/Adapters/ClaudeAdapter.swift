import Foundation

struct ClaudeAdapter: ConversationAdapter {
    let configurationDirectory: URL
    var provider: ConversationProvider { .claude }

    init(configurationDirectory: URL? = nil) {
        let configured = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
        self.configurationDirectory = configurationDirectory
            ?? URL(fileURLWithPath: configured ?? NSHomeDirectory() + "/.claude")
    }

    func discover() throws -> [Conversation] {
        let projectsDirectory = configurationDirectory.appendingPathComponent("projects")
        guard let projectDirectories = try? FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var conversations: [Conversation] = []
        for projectDirectory in projectDirectories {
            let index = loadIndex(in: projectDirectory)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDirectory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let sessionID = file.deletingPathExtension().lastPathComponent
                guard ConversationMetadata.isValidSessionID(sessionID) else { continue }
                let entry = index.entries[sessionID]
                if (entry?["isSidechain"] as? Bool) == true { continue }
                let fileMetadata = readBeginning(of: file)
                let lastRecord = readEnd(of: file)
                if fileMetadata.isSidechain { continue }
                let projectPath = (entry?["projectPath"] as? String)
                    ?? fileMetadata.cwd
                    ?? index.originalPath
                guard let projectPath else { continue }
                let title = ConversationMetadata.cleanTitle(
                    lastRecord.customTitle
                        ?? entry?["customTitle"] as? String
                        ?? fileMetadata.customTitle
                        ?? entry?["firstPrompt"] as? String
                        ?? fileMetadata.firstPrompt,
                    fallback: "Untitled conversation"
                )
                let modified = ConversationMetadata.date(entry?["modified"])
                let updatedAt = max(modified ?? .distantPast, lastRecord.updatedAt ?? .distantPast)
                conversations.append(Conversation(
                    provider: provider,
                    sessionID: sessionID,
                    projectPath: projectPath,
                    suggestedTitle: title,
                    updatedAt: updatedAt == .distantPast ? ConversationMetadata.fileModificationDate(file) : updatedAt,
                    sourceFile: file
                ))
            }
        }
        return conversations
    }

    func arguments(for conversation: Conversation, action: ConversationAction) -> [String] {
        switch action {
        case .resume: ["--resume", conversation.sessionID]
        case .branch: ["--resume", conversation.sessionID, "--fork-session"]
        }
    }

    func delete(_ conversation: Conversation) throws {
        try ClaudeConversationDeletion(configurationDirectory: configurationDirectory).delete(conversation)
    }

    private func loadIndex(in projectDirectory: URL) -> (entries: [String: [String: Any]], originalPath: String?) {
        let file = projectDirectory.appendingPathComponent("sessions-index.json")
        guard let data = try? Data(contentsOf: file),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ([:], nil)
        }
        let entries = root["entries"] as? [[String: Any]] ?? []
        var byID: [String: [String: Any]] = [:]
        for entry in entries {
            if let sessionID = entry["sessionId"] as? String { byID[sessionID] = entry }
        }
        return (byID, root["originalPath"] as? String)
    }

    private func readBeginning(of file: URL) -> (cwd: String?, firstPrompt: String?, customTitle: String?, isSidechain: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return (nil, nil, nil, false) }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 131_072) else { return (nil, nil, nil, false) }
        var cwd: String?
        var firstPrompt: String?
        var customTitle: String?
        var isSidechain = false
        for line in data.split(separator: 10, omittingEmptySubsequences: true).prefix(30) {
            guard let object = ConversationMetadata.object(from: Data(line)) else { continue }
            cwd = cwd ?? object["cwd"] as? String
            isSidechain = isSidechain || (object["isSidechain"] as? Bool == true)
            if object["type"] as? String == "custom-title" {
                customTitle = object["customTitle"] as? String
            }
            if firstPrompt == nil && object["type"] as? String == "user",
               let message = object["message"] as? [String: Any] {
                firstPrompt = message["content"] as? String
            }
            if cwd != nil && firstPrompt != nil && customTitle != nil { break }
        }
        return (cwd, firstPrompt, customTitle, isSidechain)
    }

    private func readEnd(of file: URL) -> (updatedAt: Date?, customTitle: String?) {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return (nil, nil) }
        defer { try? handle.close() }
        guard let length = try? handle.seekToEnd() else { return (nil, nil) }
        let offset = length > 262_144 ? length - 262_144 : 0
        do { try handle.seek(toOffset: offset) } catch { return (nil, nil) }
        guard let data = try? handle.readToEnd() else { return (nil, nil) }
        var lines = data.split(separator: 10, omittingEmptySubsequences: true)
        if offset > 0 && !lines.isEmpty { lines.removeFirst() }
        var updatedAt: Date?
        var customTitle: String?
        for line in lines.reversed() {
            guard let object = ConversationMetadata.object(from: Data(line)) else { continue }
            if updatedAt == nil { updatedAt = ConversationMetadata.date(object["timestamp"]) }
            if customTitle == nil && object["type"] as? String == "custom-title" {
                customTitle = object["customTitle"] as? String
            }
            if updatedAt != nil && customTitle != nil { break }
        }
        return (updatedAt, customTitle)
    }
}
