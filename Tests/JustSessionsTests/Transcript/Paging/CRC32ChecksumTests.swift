import Foundation
import Testing
@testable import JustSessions

struct CRC32ChecksumTests {
    @Test func matchesTheStandardCheckValue() {
        var checksum = CRC32Checksum()
        checksum.update(data: Data("123456789".utf8))
        #expect(checksum.finalize() == Data([0xCB, 0xF4, 0x39, 0x26]))
        #expect(CRC32Checksum().finalize() == Data(count: CRC32Checksum.byteCount))
    }

    @Test func chunksGiveTheSameChecksumAsOneRead() {
        let bytes = Data((0..<10_000).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
        var whole = CRC32Checksum()
        whole.update(data: bytes)
        for chunkSize in [1, 7, 4096, 9_999] {
            var chunked = CRC32Checksum()
            chunked.update(data: Data())
            var offset = 0
            while offset < bytes.count {
                let end = min(offset + chunkSize, bytes.count)
                bytes[offset..<end].withUnsafeBytes { chunked.update(bufferPointer: $0) }
                offset = end
            }
            #expect(chunked == whole)
        }
    }

    @Test func anyChangedByteChangesTheChecksum() {
        let bytes = Data(repeating: UInt8(ascii: "x"), count: 1_000)
        var original = CRC32Checksum()
        original.update(data: bytes)
        for position in stride(from: 0, to: bytes.count, by: 97) {
            var changed = bytes
            changed[position] = UInt8(ascii: "y")
            var checksum = CRC32Checksum()
            checksum.update(data: changed)
            #expect(checksum.finalize() != original.finalize())
        }
    }
}
