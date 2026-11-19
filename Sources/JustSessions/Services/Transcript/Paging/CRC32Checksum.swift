import Foundation
import zlib

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

    func finalize() -> Data {
        withUnsafeBytes(of: value.bigEndian) { Data($0) }
    }
}
