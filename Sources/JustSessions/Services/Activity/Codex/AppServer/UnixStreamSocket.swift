import Darwin
import Foundation

/// A blocking connection to a Unix domain socket, each read and write bounded by `timeout`. It is used from one
/// thread at a time.
final class UnixStreamSocket {
    enum SocketError: Error {
        case pathTooLong
        case failed(errno: Int32)
        case closedByPeer
    }

    private var descriptor: Int32

    /// Connects to the socket at `path`, or the socket a symbolic link there leads to. Codex links its socket from a
    /// path that may be longer than a socket address holds.
    init(connectingTo path: String, timeout: Duration) throws {
        let socketPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        var address = sockaddr_un()
        let pathBytes = Array(socketPath.utf8CString)
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw SocketError.pathTooLong }
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: pathBytes.map { UInt8(bitPattern: $0) })
        }

        descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw SocketError.failed(errno: errno) }
        // A tab started while it is open would otherwise keep the connection open after this closes it.
        CloseOnExecDescriptor.mark(descriptor)
        var socketTimeout = timeval(
            tv_sec: Int(timeout.components.seconds),
            tv_usec: Int32(timeout.components.attoseconds / 1_000_000_000_000)
        )
        var isOn: Int32 = 1
        // A write to a socket the server closed fails instead of ending the app.
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &isOn, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &socketTimeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &socketTimeout, socklen_t(MemoryLayout<timeval>.size))
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard result == 0 else {
            let connectError = errno
            close()
            throw SocketError.failed(errno: connectError)
        }
    }

    deinit {
        close()
    }

    func write(_ data: Data) throws {
        var sentByteCount = 0
        while sentByteCount < data.count {
            let result = data.withUnsafeBytes { buffer in
                send(descriptor, buffer.baseAddress! + sentByteCount, data.count - sentByteCount, 0)
            }
            guard result > 0 else { throw SocketError.failed(errno: result < 0 ? errno : EPIPE) }
            sentByteCount += result
        }
    }

    /// What arrived, waiting at most the timeout for something to.
    func read() throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 64 << 10)
        let result = recv(descriptor, &buffer, buffer.count, 0)
        if result < 0 { throw SocketError.failed(errno: errno) }
        if result == 0 { throw SocketError.closedByPeer }
        return Data(buffer[..<result])
    }

    func close() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
        descriptor = -1
    }
}
