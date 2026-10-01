import Foundation

/// Reads the protobuf fields used by Antigravity's local metadata and visible conversation steps.
enum AntigravityProtobuf {
    static func text(in data: Data, at fieldPath: [UInt64]) -> String? {
        bytes(in: data, at: fieldPath).flatMap { String(data: $0, encoding: .utf8) }
    }

    static func bytes(in data: Data, at fieldPath: [UInt64]) -> Data? {
        var fieldData = data
        for fieldNumber in fieldPath {
            guard let nextField = firstLengthDelimitedField(fieldNumber, in: fieldData) else { return nil }
            fieldData = nextField
        }
        return fieldData
    }

    static func repeatedBytes(in data: Data, field wantedField: UInt64) -> [Data] {
        (fields(in: data) ?? []).compactMap { field in
            field.number == wantedField ? field.data : nil
        }
    }

    static func integer(in data: Data, field wantedField: UInt64) -> UInt64? {
        fields(in: data)?.first { $0.number == wantedField && $0.integer != nil }?.integer
    }

    private struct Field {
        let number: UInt64
        var data: Data?
        var integer: UInt64?
    }

    private static func firstLengthDelimitedField(_ wantedField: UInt64, in data: Data) -> Data? {
        fields(in: data)?.first { $0.number == wantedField && $0.data != nil }?.data
    }

    private static func fields(in data: Data) -> [Field]? {
        let bytes = Array(data)
        var position = 0
        var fields: [Field] = []
        while position < bytes.count {
            guard let key = readVarint(bytes, position: &position), key >> 3 > 0 else { return nil }
            let fieldNumber = key >> 3
            let wireType = key & 7
            switch wireType {
            case 0:
                guard let integer = readVarint(bytes, position: &position) else { return nil }
                fields.append(Field(number: fieldNumber, integer: integer))
            case 1:
                guard advance(8, position: &position, count: bytes.count) else { return nil }
            case 2:
                guard let length = readVarint(bytes, position: &position),
                      length <= UInt64(bytes.count - position) else { return nil }
                let end = position + Int(length)
                fields.append(Field(number: fieldNumber, data: Data(bytes[position..<end])))
                position = end
            case 5:
                guard advance(4, position: &position, count: bytes.count) else { return nil }
            default:
                return nil
            }
        }
        return fields
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
