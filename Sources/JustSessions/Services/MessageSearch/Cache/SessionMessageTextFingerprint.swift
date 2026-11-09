import Foundation

/// Tells a session's saved text from stale text: the session's last activity, and its file's size and modification
/// date and file identity. OpenCode keeps every session in one database, which changes with any of them, so its sessions go by their own
/// last activity alone.
struct SessionMessageTextFingerprint: Sendable, Codable, Equatable {
    let sourceFilePath: String
    let updatedAt: Date
    let byteCount: UInt64?
    let modifiedAt: Date?
    let device: UInt64?
    let inode: UInt64?

    init(_ conversation: Conversation) {
        sourceFilePath = conversation.sourceFile.path
        updatedAt = conversation.updatedAt
        guard conversation.provider != .opencode,
              let attributes = try? FileManager.default.attributesOfItem(atPath: conversation.sourceFile.path) else {
            byteCount = nil
            modifiedAt = nil
            device = nil
            inode = nil
            return
        }
        byteCount = (attributes[.size] as? NSNumber)?.uint64Value
        modifiedAt = attributes[.modificationDate] as? Date
        device = (attributes[.systemNumber] as? NSNumber)?.uint64Value
        inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
    }
}
