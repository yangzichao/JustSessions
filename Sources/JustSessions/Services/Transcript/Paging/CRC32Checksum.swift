import Foundation
import zlib

/// CRC-32 of bytes fed in chunks, as zlib computes it. It tells whether a session log's earlier bytes changed under a
/// CLI, an editor or a mirror copy. Nobody chooses those bytes to fool the check, so SHA-256's resistance to deliberate
/// collisions isn't needed, and it costs about 14 times as much CPU per byte. A CRC-32 catches every change confined to
/// 32 consecutive bits and misses about one in four billion other changes. Not for naming content, as image or host
/// identities do.
struct CRC32Checksum: Sendable, Equatable {
    static let byteCount = 4
    private var value: UInt32 = 0

    mutating func update(data: Data) {
        data.withUnsafeBytes { update(bufferPointer: $0) }
    }

    mutating func update(bufferPointer: UnsafeRawBufferPointer) {
        guard let base = bufferPointer.baseAddress, !bufferPointer.isEmpty else { return }
        value = UInt32(crc32_z(uLong(value), base.assumingMemoryBound(to: Bytef.self), bufferPointer.count))
    }

    /// The four checksum bytes, most significant first.
    func finalize() -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
