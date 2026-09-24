import Foundation

/// Reads only the length-delimited fields needed from Antigravity's local metadata.
enum AntigravityProtobuf {
    static func text(in data: Data, at fieldPath: [UInt64]) -> String? {
        var fieldData = data
        for fieldNumber in fieldPath {
            guard let nextField = firstLengthDelimitedField(fieldNumber, in: fieldData) else { return nil }
            fieldData = nextField
        }
        return String(data: fieldData, encoding: .utf8)
    }

    private static func firstLengthDelimitedField(_ wantedField: UInt64, in data: Data) -> Data? {
        let bytes = Array(data)
        var position = 0
        while position < bytes.count {
            guard let key = readVarint(bytes, position: &position) else { return nil }
            let fieldNumber = key >> 3
            let wireType = key & 7
            switch wireType {
            case 0:
                guard readVarint(bytes, position: &position) != nil else { return nil }
            case 1:
                guard advance(8, position: &position, count: bytes.count) else { return nil }
            case 2:
                guard let length = readVarint(bytes, position: &position),
                      length <= UInt64(bytes.count - position) else { return nil }
                let end = position + Int(length)
                if fieldNumber == wantedField { return Data(bytes[position..<end]) }
                position = end
            case 5:
                guard advance(4, position: &position, count: bytes.count) else { return nil }
            default:
                return nil
            }
        }
        return nil
    }

    private static func readVarint(_ bytes: [UInt8], position: inout Int) -> UInt64? {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard position < bytes.count else { return nil }
            let byte = bytes[position]
            position += 1
            if shift == 63 && byte > 1 { return nil }
            value |= UInt64(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
        }
        return nil
    }

    private static func advance(_ amount: Int, position: inout Int, count: Int) -> Bool {
        guard amount <= count - position else { return false }
        position += amount
        return true
    }
}
