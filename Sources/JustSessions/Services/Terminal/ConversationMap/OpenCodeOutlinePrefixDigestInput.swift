import CryptoKit
import Foundation
import SQLite3

struct OpenCodeOutlinePrefixDigestInput {
    enum Marker: UInt8 {
        case messageStart = 1
        case part = 2
        case messageEnd = 3
    }

    private static let nullColumnLength = UInt64.max
    private static let capacity = 64 << 10
    private var hasher: SHA256
    private var pending = Data()

    init(hasher: SHA256) {
        self.hasher = hasher
        pending.reserveCapacity(Self.capacity)
    }

    mutating func append(_ marker: Marker) {
        if pending.count == Self.capacity { flush() }
        pending.append(marker.rawValue)
    }

    mutating func appendInteger(_ value: UInt64) {
        var value = value.bigEndian
        withUnsafeBytes(of: &value) { appendBytes($0) }
    }

    mutating func appendColumn(_ column: Int32, of statement: OpaquePointer) {
        let isNull = sqlite3_column_type(statement, column) == SQLITE_NULL
        let count = Int(sqlite3_column_bytes(statement, column))
        appendInteger(isNull ? Self.nullColumnLength : UInt64(count))
        if let bytes = sqlite3_column_blob(statement, column), count > 0 {
            appendBytes(UnsafeRawBufferPointer(start: bytes, count: count))
        }
    }

    private mutating func appendBytes(_ bytes: UnsafeRawBufferPointer) {
        if pending.count + bytes.count > Self.capacity { flush() }
        if bytes.count > Self.capacity { hasher.update(bufferPointer: bytes) } else { pending.append(contentsOf: bytes) }
    }

    private mutating func flush() {
        if !pending.isEmpty {
            hasher.update(data: pending)
            pending.removeAll(keepingCapacity: true)
        }
    }

    mutating func finish() -> SHA256 {
        flush()
        return hasher
    }
}
