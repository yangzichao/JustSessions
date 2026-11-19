import Foundation

final class CodexAppServerConnection {
    enum ConnectionError: Error {
        case upgradeRefused
        case closedByServer
        case unreadableResponse
    }

    private let socket: UnixStreamSocket
    private var reader = WebSocketMessageReader()
    private var nextRequestID = 0

    /// Connects and introduces the app, as each client of the server does first.
    init(socketPath: String, timeout: Duration, clientVersion: String) throws {
        socket = try UnixStreamSocket(connectingTo: socketPath, timeout: timeout)
        try socket.write(WebSocketClientFrame.upgradeRequest(key: WebSocketClientFrame.randomUpgradeKey()))
        var head = Data()
        let headEnd = Data("\r\n\r\n".utf8)
        while head.range(of: headEnd) == nil {
            guard head.count < 16 << 10 else { throw ConnectionError.upgradeRefused }
            head.append(try socket.read())
        }
        let bodyStart = head.range(of: headEnd)!.upperBound
        guard WebSocketClientFrame.acceptsUpgrade(head[..<bodyStart]) else { throw ConnectionError.upgradeRefused }
        reader.append(Data(head[bodyStart...]))

        _ = try request("initialize", params: ["clientInfo": ["name": "JustSessions", "version": clientVersion]])
        try send(["jsonrpc": "2.0", "method": "initialized"])
    }

    func request(_ method: String, params: [String: Any]) throws -> [String: Any]? {
        nextRequestID += 1
        let requestID = nextRequestID
        try send(["jsonrpc": "2.0", "id": requestID, "method": method, "params": params])
        while true {
            let message = try nextMessage()
            guard message["method"] == nil, (message["id"] as? Int) == requestID else { continue }
            return message["result"] as? [String: Any]
        }
    }

    func close() {
        socket.close()
    }

    private func send(_ message: [String: Any]) throws {
        let payload = try JSONSerialization.data(withJSONObject: message)
        try socket.write(WebSocketClientFrame.frame(.text, payload: payload))
    }

    private func nextMessage() throws -> [String: Any] {
        while true {
            switch try reader.nextMessage() {
            case .text(let payload):
                guard let message = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] else {
                    throw ConnectionError.unreadableResponse
                }
                return message
            case .ping(let payload):
                try socket.write(WebSocketClientFrame.frame(.pong, payload: payload))
            case .close:
                throw ConnectionError.closedByServer
            case nil:
                reader.append(try socket.read())
            }
        }
    }
}
