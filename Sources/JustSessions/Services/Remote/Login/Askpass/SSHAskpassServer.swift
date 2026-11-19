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
        guard let connection = SSHAskpassConnection.accept(on: listeningDescriptor) else { return }
        let connectionQueue = DispatchQueue(label: "SSHAskpassServer.connection", qos: .userInitiated)
        connectionQueue.async { [self] in serve(connection, on: connectionQueue) }
    }

    private func serve(_ connection: SSHAskpassConnection, on connectionQueue: DispatchQueue) {
        guard connection.prepare(requestTimeout: Self.requestTimeout), let request = connection.readRequest() else {
            connection.close()
            return
        }
        let id = UUID()
        let hangUpWatch = connection.watchForHangUp(on: connectionQueue)
        let task = Task { [ask] in
            let reply = await ask(request)
            if let message = SSHAskpassMessageLine.encoded(reply) { connection.send(message) }
            hangUpWatch?.stop()
            connection.close()
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
}
