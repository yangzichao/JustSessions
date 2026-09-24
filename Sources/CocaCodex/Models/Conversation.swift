import Foundation

enum ConversationProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex"
    case antigravity = "Antigravity"

    var id: String { rawValue }
    var symbolName: String {
        switch self {
        case .claude: "sparkle"
        case .codex: "terminal"
        case .antigravity: "sparkles"
        }
    }

    var supportsBranchFromLauncher: Bool { self != .antigravity }
    var supportsDeletionFromLauncher: Bool { self != .antigravity }
}

struct Conversation: Identifiable, Sendable {
    let provider: ConversationProvider
    let sessionID: String
    let projectPath: String
    let suggestedTitle: String
    let updatedAt: Date
    let sourceFile: URL

    var id: String { "\(provider.rawValue):\(sessionID)" }
    var projectName: String {
        URL(fileURLWithPath: projectPath).lastPathComponent
    }
    var projectDirectoryKey: String {
        URL(fileURLWithPath: projectPath).standardizedFileURL.resolvingSymlinksInPath().path
    }
    var isProjectAvailable: Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: projectPath, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
