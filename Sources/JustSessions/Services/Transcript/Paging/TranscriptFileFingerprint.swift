import Darwin
import Foundation

/// Read from the open descriptor, avoiding URL resource-value caches and path-replacement races.
struct TranscriptFileFingerprint: Sendable, Equatable {
    let device: Int32
    let inode: UInt64
    let byteCount: UInt64
    let modifiedSeconds: Int
    let modifiedNanoseconds: Int

    init(handle: FileHandle) throws {
        var info = stat()
        guard fstat(handle.fileDescriptor, &info) == 0, info.st_size >= 0 else { throw TranscriptPagingError.sourceChanged }
        device = info.st_dev
        inode = info.st_ino
        byteCount = UInt64(info.st_size)
        modifiedSeconds = info.st_mtimespec.tv_sec
        modifiedNanoseconds = info.st_mtimespec.tv_nsec
    }

    func identifiesSameFile(as other: Self) -> Bool { device == other.device && inode == other.inode }
}
