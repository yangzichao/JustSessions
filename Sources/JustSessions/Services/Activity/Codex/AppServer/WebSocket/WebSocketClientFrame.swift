import Foundation

/// The little of WebSocket (RFC 6455) the app speaks to Codex's background server over its Unix socket, where
/// Network.framework's own WebSocket protocol fails to connect.
enum WebSocketOpcode: UInt8, Sendable {
    case continuation = 0x0
    case text = 0x1
    case binary = 0x2
    case close = 0x8
    case ping = 0x9
    case pong = 0xA
}

enum WebSocketClientFrame {
    /// The request that turns the connection into a WebSocket. `key` is 16 random bytes in base64.
    static func upgradeRequest(key: String) -> Data {
        Data(
            ("GET / HTTP/1.1\r\nHost: localhost\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                + "Sec-WebSocket-Key: \(key)\r\nSec-WebSocket-Version: 13\r\n\r\n").utf8)
    }

    static func randomUpgradeKey() -> String {
        Data((0..<16).map { _ in UInt8.random(in: .min ... .max) }).base64EncodedString()
    }

    static func acceptsUpgrade(_ responseHead: Data) -> Bool {
        responseHead.starts(with: Data("HTTP/1.1 101".utf8))
    }

    /// One whole frame. A client masks every frame it sends with 4 bytes of its own.
    static func frame(_ opcode: WebSocketOpcode, payload: Data, mask: [UInt8] = randomMask()) -> Data {
        var frame = Data([0x80 | opcode.rawValue])
        switch payload.count {
        case ..<126:
            frame.append(0x80 | UInt8(payload.count))
        case ..<65_536:
            frame.append(0x80 | 126)
            frame.append(contentsOf: withUnsafeBytes(of: UInt16(payload.count).bigEndian, Array.init))
        default:
            frame.append(0x80 | 127)
            frame.append(contentsOf: withUnsafeBytes(of: UInt64(payload.count).bigEndian, Array.init))
        }
        frame.append(contentsOf: mask)
        frame.append(contentsOf: payload.enumerated().map { index, byte in byte ^ mask[index % 4] })
        return frame
    }

    static func randomMask() -> [UInt8] {
        (0..<4).map { _ in UInt8.random(in: .min ... .max) }
    }
}
