import Darwin

/// For a SQLite source, also its `-wal`, which is written first.
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
            conversation.provider.storesSessionsInSQLite ? Self.stamp(atPath: conversation.sourceFile.path + "-wal") : nil
    }

    static func stamp(atPath path: String) -> FileStamp? {
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return FileStamp(
            device: info.st_dev, inode: info.st_ino, byteCount: info.st_size,
            seconds: info.st_mtimespec.tv_sec, nanoseconds: info.st_mtimespec.tv_nsec)
    }
}
