import Darwin
import Foundation

final class SSHAskpassConnection: @unchecked Sendable {
    private let descriptor: Int32
    private let lock = NSLock()
    private var isClosed = false

    init(adopting descriptor: Int32) {
        self.descriptor = descriptor
    }

    deinit {
        close()
    }

    static func accept(on listeningDescriptor: Int32) -> SSHAskpassConnection? {
        let descriptor = Darwin.accept(listeningDescriptor, nil, nil)
        guard descriptor >= 0 else { return nil }
        CloseOnExecDescriptor.mark(descriptor)
        return SSHAskpassConnection(adopting: descriptor)
    }

    /// Blocking, with a time limit for the question; false for a connection from another user, or one whose helper has
    /// already gone. macOS refuses `SO_NOSIGPIPE` on a socket closed at both ends, and a reply sent there without it
    /// would end the app with `SIGPIPE`.
    func prepare(requestTimeout: TimeInterval) -> Bool {
        var userID: uid_t = 0
        var groupID: gid_t = 0
        guard getpeereid(descriptor, &userID, &groupID) == 0, userID == getuid() else { return false }
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0 else { return false }
        var isOn: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &isOn, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return false }
        var timeout = timeval(tv_sec: Int(requestTimeout), tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        return true
    }

    func readRequest() -> SSHAskpassRequest? {
        var received = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while !received.contains(UInt8(ascii: "\n")) {
            guard received.count < SSHAskpassMessageLine.maximumLength else { return nil }
            let count = recv(descriptor, &buffer, buffer.count, 0)
            guard count > 0 else { return nil }
            received.append(contentsOf: buffer[..<count])
        }
        return SSHAskpassMessageLine.decoded(SSHAskpassRequest.self, from: received)
    }

    func send(_ data: Data) {
        var sentCount = 0
        while sentCount < data.count {
            let count = data.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress! + sentCount, data.count - sentCount, 0) }
            guard count > 0 else { return }
            sentCount += count
        }
    }

    func watchForHangUp(on queue: DispatchQueue) -> HangUpWatch? {
        HangUpWatch(copying: descriptor, queue: queue)
    }

    func close() {
        let wasClosed = lock.withLock {
            defer { isClosed = true }
            return isClosed
        }
        if !wasClosed { Darwin.close(descriptor) }
    }

    final class HangUpWatch: @unchecked Sendable {
        private let source: DispatchSourceRead
        private let lock = NSLock()
        private var isStopped = false

        fileprivate init?(copying descriptor: Int32, queue: DispatchQueue) {
            let copy = CloseOnExecDescriptor.duplicate(descriptor)
            guard copy >= 0 else { return nil }
            source = DispatchSource.makeReadSource(fileDescriptor: copy, queue: queue)
            source.setCancelHandler { Darwin.close(copy) }
        }

        func start(onHangUp: @escaping @Sendable () -> Void) {
            source.setEventHandler { [weak self] in
                self?.stop()
                onHangUp()
            }
            source.resume()
        }

        func stop() {
            let wasStopped = lock.withLock {
                defer { isStopped = true }
                return isStopped
            }
            if !wasStopped { source.cancel() }
        }
    }
}
