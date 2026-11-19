import Foundation

struct WebSocketMessageReader {
    enum Message: Equatable {
        case text(Data)
        case ping(Data)
        case close
    }

    enum ReadError: Error {
        case frameTooLong
    }

    static let largestFrameByteCount = 64 << 20

    private var unread = Data()
    private var fragments = Data()

    mutating func append(_ bytes: Data) {
        unread.append(bytes)
    }

    mutating func nextMessage() throws -> Message? {
        while let frame = try nextFrame() {
            switch frame.opcode {
            case .ping:
                return .ping(frame.payload)
            case .close:
                return .close
            case .pong:
                continue
            case .text, .binary, .continuation:
                fragments.append(frame.payload)
                guard frame.isFinal else { continue }
                defer { fragments = Data() }
                return .text(fragments)
            }
        }
        return nil
    }

    private mutating func nextFrame() throws -> (opcode: WebSocketOpcode, isFinal: Bool, payload: Data)? {
        let bytes = [UInt8](unread.prefix(14))
        guard bytes.count >= 2 else { return nil }
        let isMasked = bytes[1] & 0x80 != 0
        var headerLength = 2
        var payloadLength = Int(bytes[1] & 0x7F)
        if payloadLength == 126 {
            guard bytes.count >= 4 else { return nil }
            payloadLength = Int(bytes[2]) << 8 | Int(bytes[3])
            headerLength = 4
        } else if payloadLength == 127 {
            guard bytes.count >= 10 else { return nil }
            let length = bytes[2..<10].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
            guard length <= UInt64(Self.largestFrameByteCount) else { throw ReadError.frameTooLong }
            payloadLength = Int(length)
            headerLength = 10
        }
        guard payloadLength <= Self.largestFrameByteCount else { throw ReadError.frameTooLong }
        let maskLength = isMasked ? 4 : 0
        guard unread.count >= headerLength + maskLength + payloadLength else { return nil }

        let start = unread.startIndex
        let mask = isMasked ? [UInt8](unread[(start + headerLength)..<(start + headerLength + 4)]) : []
        let payloadStart = start + headerLength + maskLength
        var payload = Data(unread[payloadStart..<(payloadStart + payloadLength)])
        if isMasked {
            payload = Data(payload.enumerated().map { index, byte in byte ^ mask[index % 4] })
        }
        unread = Data(unread[(payloadStart + payloadLength)...])
        let opcode = WebSocketOpcode(rawValue: bytes[0] & 0x0F) ?? .close
        return (opcode, bytes[0] & 0x80 != 0, payload)
    }
}
