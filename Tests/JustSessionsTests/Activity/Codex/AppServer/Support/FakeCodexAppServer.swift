import Darwin
import Foundation

@testable import JustSessions

final class FakeCodexAppServer: @unchecked Sendable {
    static var waitingOnApproval: [String: Any] { ["type": "active", "activeFlags": ["waitingOnApproval"]] }
    static var waitingOnUserInput: [String: Any] { ["type": "active", "activeFlags": ["waitingOnUserInput"]] }
    static var working: [String: Any] { ["type": "active", "activeFlags": [String]()] }
    static var idle: [String: Any] { ["type": "idle"] }

    let socketPath: String
    private let listeningDescriptor: Int32
    private let lock = NSLock()
    private var statusesByLoadedThreadID: [String: [String: Any]] = [:]
    private var receivedMethods: [String] = []
    private var acceptedConnectionCount = 0
    private var openConnectionCount = 0
    private var isAnswering = true
    private var isStopped = false

    /// Listens at `socketPath`, and links Codex's socket path in `codexDirectory` to it as Codex does, since that
    /// path may be longer than a socket address holds.
    init(socketPath: String, linkedFrom codexDirectory: URL) throws {
        self.socketPath = socketPath
        unlink(socketPath)
        listeningDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8CString).map { UInt8(bitPattern: $0) }
        precondition(pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path), "\(socketPath) is too long")
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listeningDescriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(listeningDescriptor, 8) == 0 else {
            throw UnixStreamSocket.SocketError.failed(errno: errno)
        }
        let link = codexDirectory.appendingPathComponent("app-server-control/app-server-control.sock")
        try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.removeItem(at: link)
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: socketPath)
        Thread.detachNewThread { [self] in acceptConnections() }
    }

    deinit {
        stop()
    }

    func setStatus(_ status: [String: Any]?, ofThread threadID: String) {
        lock.withLock { statusesByLoadedThreadID[threadID] = status }
    }

    func setAnswering(_ isAnswering: Bool) {
        lock.withLock { self.isAnswering = isAnswering }
    }

    var methods: [String] { lock.withLock { receivedMethods } }
    var connectionCount: Int { lock.withLock { acceptedConnectionCount } }
    var openConnections: Int { lock.withLock { openConnectionCount } }

    func stop() {
        let wasStopped = lock.withLock {
            defer { isStopped = true }
            return isStopped
        }
        guard !wasStopped else { return }
        Darwin.close(listeningDescriptor)
        unlink(socketPath)
    }

    private var stopped: Bool { lock.withLock { isStopped } }

    private func acceptConnections() {
        while !stopped {
            guard waitUntilReadable(listeningDescriptor) else { continue }
            let client = accept(listeningDescriptor, nil, nil)
            guard client >= 0 else { continue }
            var isOn: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &isOn, socklen_t(MemoryLayout<Int32>.size))
            lock.withLock {
                acceptedConnectionCount += 1
                openConnectionCount += 1
            }
            Thread.detachNewThread { [self] in
                serve(client)
                Darwin.close(client)
                lock.withLock { openConnectionCount -= 1 }
            }
        }
    }

    private func serve(_ client: Int32) {
        var head = Data()
        while head.range(of: Data("\r\n\r\n".utf8)) == nil {
            guard let bytes = read(client) else { return }
            head.append(bytes)
        }
        write(Data("HTTP/1.1 101 Switching Protocols\r\nconnection: Upgrade\r\nupgrade: websocket\r\n\r\n".utf8), to: client)
        write(Self.frame(.ping, payload: Data("are you there".utf8)), to: client)
        var reader = WebSocketMessageReader()
        while let bytes = read(client) {
            reader.append(bytes)
            while let message = try? reader.nextMessage() {
                switch message {
                case .close:
                    return
                case .ping:
                    continue
                case .text(let payload):
                    guard let request = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                        let method = request["method"] as? String
                    else { continue }
                    let isAnswering = lock.withLock {
                        receivedMethods.append(method)
                        return self.isAnswering
                    }
                    guard isAnswering, let requestID = request["id"] else { continue }
                    send(["jsonrpc": "2.0", "method": "account/updated", "params": [String: Any]()], to: client)
                    var response: [String: Any] = ["jsonrpc": "2.0", "id": requestID]
                    if let result = result(of: method, params: request["params"] as? [String: Any] ?? [:]) {
                        response["result"] = result
                    } else {
                        response["error"] = ["code": -32600, "message": "\(method) is not answered here"]
                    }
                    send(response, to: client)
                }
            }
        }
    }

    private func result(of method: String, params: [String: Any]) -> [String: Any]? {
        lock.withLock {
            switch method {
            case "initialize":
                return ["userAgent": "fake", "codexHome": "/fake", "platformFamily": "unix", "platformOs": "macos"]
            case "thread/loaded/list":
                return ["data": statusesByLoadedThreadID.keys.sorted()]
            case "thread/read":
                guard let threadID = params["threadId"] as? String, let status = statusesByLoadedThreadID[threadID] else {
                    return nil
                }
                return ["thread": ["id": threadID, "preview": String(repeating: "a long first prompt ", count: 10), "status": status]]
            default:
                return nil
            }
        }
    }

    private func send(_ message: [String: Any], to client: Int32) {
        guard let payload = try? JSONSerialization.data(withJSONObject: message) else { return }
        write(Self.frame(.text, payload: payload), to: client)
    }

    /// A server's frames are not masked.
    private static func frame(_ opcode: WebSocketOpcode, payload: Data) -> Data {
        var frame = Data([0x80 | opcode.rawValue])
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else {
            frame.append(126)
            frame.append(contentsOf: [UInt8(payload.count >> 8), UInt8(payload.count & 0xFF)])
        }
        return frame + payload
    }

    private func read(_ client: Int32) -> Data? {
        while !stopped {
            guard waitUntilReadable(client) else { continue }
            guard !stopped else { return nil }
            var buffer = [UInt8](repeating: 0, count: 64 << 10)
            let count = recv(client, &buffer, buffer.count, 0)
            return count > 0 ? Data(buffer[..<count]) : nil
        }
        return nil
    }

    private func write(_ data: Data, to client: Int32) {
        data.withUnsafeBytes { _ = Darwin.send(client, $0.baseAddress!, data.count, 0) }
    }

    private func waitUntilReadable(_ descriptor: Int32) -> Bool {
        var request = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
        return poll(&request, 1, 100) > 0
    }
}
