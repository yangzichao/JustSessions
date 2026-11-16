import Foundation

/// A window's outstanding work for a host. Lifecycle epochs survive removal, so removing and adding the same
/// destination cannot make an old callback current again. The registry's host gate owns disk exclusion separately.
@MainActor
final class RemoteHostWork {
    struct Token: Equatable, Sendable {
        let lifecycle: UInt64
        let operation: UInt64
        let read: UInt64
    }

    private var lifecycles: [String: UInt64] = [:]
    private var operations: [String: UInt64] = [:]
    private var reads: [String: UInt64] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    private var auxiliaryTasks: [String: [UUID: Task<Void, Never>]] = [:]
    private var previousStatuses: [String: HostRefreshStatus] = [:]
    private var latestCopies: [String: Date] = [:]

    deinit {
        for task in tasks.values { task.cancel() }
        for jobs in auxiliaryTasks.values { for task in jobs.values { task.cancel() } }
    }

    func lifecycle(on host: String) -> UInt64 { lifecycles[host, default: 0] }

    func beginRefresh(on host: String, previousStatus: HostRefreshStatus?) -> Token {
        operations[host, default: 0] &+= 1
        reads[host, default: 0] &+= 1
        previousStatuses[host] = previousStatus
        return token(on: host)
    }

    func keep(_ task: Task<Void, Never>, on host: String, token: Token) {
        guard isCurrent(token, on: host) else { task.cancel(); return }
        tasks[host] = task
    }

    func finishRefresh(on host: String, token: Token) {
        guard isCurrent(token, on: host) else { return }
        tasks[host] = nil
        previousStatuses[host] = nil
    }

    func previousStatus(on host: String) -> HostRefreshStatus? { previousStatuses[host] }

    func keepAuxiliary(_ task: Task<Void, Never>, on host: String) {
        let id = UUID()
        auxiliaryTasks[host, default: [:]][id] = task
        Task { [weak self] in
            await task.value
            self?.auxiliaryTasks[host]?[id] = nil
        }
    }

    @discardableResult
    func invalidate(_ host: String) -> Task<Void, Never>? {
        lifecycles[host, default: 0] &+= 1
        operations[host, default: 0] &+= 1
        reads[host, default: 0] &+= 1
        latestCopies[host] = nil
        let task = tasks.removeValue(forKey: host)
        task?.cancel()
        if let jobs = auxiliaryTasks.removeValue(forKey: host) { for job in jobs.values { job.cancel() } }
        previousStatuses[host] = nil
        return task
    }

    /// Only the newest listing request may publish, including requests whose disk reads finish out of order.
    func beginRead(on host: String, copiedAt: Date? = nil) -> Token? {
        if let copiedAt {
            guard copiedAt >= latestCopies[host, default: .distantPast] else { return nil }
            latestCopies[host] = copiedAt
        }
        reads[host, default: 0] &+= 1
        return token(on: host)
    }

    func isCurrent(_ token: Token, on host: String) -> Bool {
        token.lifecycle == lifecycle(on: host) && token.operation == operations[host, default: 0]
    }

    func isCurrentRead(_ token: Token, on host: String) -> Bool {
        isCurrent(token, on: host) && token.read == reads[host, default: 0]
    }

    private func token(on host: String) -> Token {
        Token(lifecycle: lifecycle(on: host), operation: operations[host, default: 0], read: reads[host, default: 0])
    }
}

extension ConversationStore {
    func cancelRemoteHostRefreshes() {
        for host in remoteHostList.hosts { invalidateRemoteHostWork(on: host) }
    }

    func hostLifecycleGeneration(on host: SessionHost) -> UInt64 {
        host.sshDestination.map { remoteHostWork.lifecycle(on: $0) } ?? 0
    }

    func isCurrentHostLifecycle(_ generation: UInt64, on host: SessionHost) -> Bool {
        guard !isTearingDownWorkspace else { return false }
        guard let destination = host.sshDestination else { return generation == 0 }
        return remoteHostList.hosts.contains(destination) && !isDisconnected(destination)
            && remoteHostWork.lifecycle(on: destination) == generation
    }

    @discardableResult
    func invalidateRemoteHostWork(on host: String) -> Task<Void, Never>? {
        let previousStatus = remoteHostWork.previousStatus(on: host)
        let task = remoteHostWork.invalidate(host)
        if hostRefreshStatuses[.ssh(host)] == .refreshing { hostRefreshStatuses[.ssh(host)] = previousStatus }
        remoteSessionCopySteps[.ssh(host)] = nil
        hostsCheckingShellStartup.remove(host)
        return task
    }
}
