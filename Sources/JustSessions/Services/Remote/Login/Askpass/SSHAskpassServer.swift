import Darwin
import Foundation

final class SSHAskpassServer: @unchecked Sendable {
    let socketPath: String
    private let ask: @Sendable (SSHAskpassRequest) async -> SSHAskpassReply
    private let acceptSource: DispatchSourceRead
    private let lock = NSLock()
    private var questionTasks: [UUID: Task<Void, Never>] = [:]
    private var isStopped = false

    static let requestTimeout: TimeInterval = 10

    init?(socketPath: String, ask: @escaping @Sendable (SSHAskpassRequest) async -> SSHAskpassReply) {
        guard let descriptor = Self.listeningSocket(at: socketPath) else { return nil }
        self.socketPath = socketPath
        self.ask = ask
        // The server's own queues get a thread even while busy Swift tasks fill every core. Work on a global queue
        // waits until they finish, and the question with it.
        let acceptQueue = DispatchQueue(label: "SSHAskpassServer.accept", qos: .userInitiated)
        acceptSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: acceptQueue)
        acceptSource.setEventHandler { [weak self] in self?.acceptConnection(on: descriptor) }
        acceptSource.setCancelHandler { Darwin.close(descriptor) }
        acceptSource.resume()
    }

    deinit {
        stop()
    }

    func stop() {
        let tasks: [Task<Void, Never>]? = lock.withLock {
            guard !isStopped else { return nil }
            isStopped = true
            return Array(questionTasks.values)
        }
        guard let tasks else { return }
        unlink(socketPath)
        acceptSource.cancel()
        for task in tasks { task.cancel() }
    }

    private static func listeningSocket(at path: String) -> Int32? {
        var address = sockaddr_un()
        let pathBytes = Array(path.utf8CString).map { UInt8(bitPattern: $0) }
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        address.sun_family = sa_family_t(AF_UNIX)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: pathBytes) }
        unlink(path)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return nil }
        CloseOnExecDescriptor.mark(descriptor)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        // Non-blocking, so a connection that went away before it was accepted can't hold up the queue.
        guard bound == 0, listen(descriptor, 4) == 0, fcntl(descriptor, F_SETFL, O_NONBLOCK) == 0 else {
            Darwin.close(descriptor)
            unlink(path)
            return nil
        }
        return descriptor
    }

    private func acceptConnection(on listeningDescriptor: Int32) {
        let descriptor = accept(listeningDescriptor, nil, nil)
        guard descriptor >= 0 else { return }
        CloseOnExecDescriptor.mark(descriptor)
        let connectionQueue = DispatchQueue(label: "SSHAskpassServer.connection", qos: .userInitiated)
        connectionQueue.async { [self] in serve(descriptor, on: connectionQueue) }
    }

    private func serve(_ descriptor: Int32, on connectionQueue: DispatchQueue) {
        guard Self.prepare(descriptor), let request = Self.readRequest(from: descriptor) else {
            Darwin.close(descriptor)
            return
        }
        let id = UUID()
        let hangUpWatch = HangUpWatch(copying: descriptor, queue: connectionQueue)
        let task = Task { [ask] in
            let reply = await ask(request)
            if let message = SSHAskpassMessageLine.encoded(reply) { Self.send(message, to: descriptor) }
            hangUpWatch?.stop()
            Darwin.close(descriptor)
        }
        let isStopped = lock.withLock {
            if !self.isStopped { questionTasks[id] = task }
            return self.isStopped
        }
        if isStopped { task.cancel() }
        hangUpWatch?.start { task.cancel() }
        Task { [weak self] in
            await task.value
            _ = self?.lock.withLock { self?.questionTasks.removeValue(forKey: id) }
        }
    }

    /// Blocking, with a time limit for the question; false for a connection from another user, or one whose helper has
    /// already gone. macOS refuses `SO_NOSIGPIPE` on a socket closed at both ends, and a reply sent there without it
    /// would end the app with `SIGPIPE`.
    static func prepare(_ descriptor: Int32) -> Bool {
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

    private static func readRequest(from descriptor: Int32) -> SSHAskpassRequest? {
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

    private static func send(_ data: Data, to descriptor: Int32) {
        var sentCount = 0
        while sentCount < data.count {
            let count = data.withUnsafeBytes { Darwin.send(descriptor, $0.baseAddress! + sentCount, data.count - sentCount, 0) }
            guard count > 0 else { return }
            sentCount += count
        }
    }

    private final class HangUpWatch: @unchecked Sendable {
        private let source: DispatchSourceRead
        private let lock = NSLock()
        private var isStopped = false

        init?(copying descriptor: Int32, queue: DispatchQueue) {
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
