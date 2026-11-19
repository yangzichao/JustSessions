import Darwin

/// A session file's device, inode, size, and modification time by `stat`, and for a SQLite source its `-wal`'s, which is
/// written first (ConversationStore+NewSessionDiscovery.swift:73-77). Microseconds; run on the outline reader's actor.
struct ConversationOutlineChangeStamp: Equatable, Sendable {
    struct FileStamp: Equatable, Sendable {
        let device: Int32
        let inode: UInt64
        let byteCount: Int64
        let seconds: Int
        let nanoseconds: Int
    }

    let file: FileStamp?
    let writeAheadLog: FileStamp?

    init(of conversation: Conversation) {
        file = Self.stamp(atPath: conversation.sourceFile.path)
        writeAheadLog =
            conversation.provider == .opencode || conversation.provider == .antigravity
            ? Self.stamp(atPath: conversation.sourceFile.path + "-wal") : nil
    }

    static func stamp(atPath path: String) -> FileStamp? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return FileStamp(
            device: info.st_dev, inode: info.st_ino, byteCount: info.st_size,
            seconds: info.st_mtimespec.tv_sec, nanoseconds: info.st_mtimespec.tv_nsec)
    }
}
