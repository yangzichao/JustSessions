import Foundation

/// Serializes disk work for a host across workspace windows. The operation keeps its reservation until it actually
/// ends, even when its window closes or its caller cancels; unrelated hosts can still work independently.
actor HostSessionWorkCoordinator {
    private struct Waiter {
        let id: UUID
        let hosts: Set<SessionHost>
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var reservations: [UUID: Set<SessionHost>] = [:]
    private var waiters: [Waiter] = []

    func withAccess<Value: Sendable>(
        to hosts: Set<SessionHost>,
        operation: @Sendable () async throws -> Value
    ) async throws -> Value {
        let id = UUID()
        try await acquire(id, hosts: hosts)
        defer { release(id) }
        try Task.checkCancellation()
        return try await operation()
    }

    private func acquire(_ id: UUID, hosts: Set<SessionHost>) async throws {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, hosts: hosts, continuation: continuation))
                resumeAvailableWaiters()
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
        resumeAvailableWaiters()
    }

    private func release(_ id: UUID) {
        reservations.removeValue(forKey: id)
        resumeAvailableWaiters()
    }

    private func resumeAvailableWaiters() {
        var occupied = reservations.values.reduce(into: Set<SessionHost>()) { $0.formUnion($1) }
        var remaining: [Waiter] = []
        for waiter in waiters {
            if occupied.isDisjoint(with: waiter.hosts) {
                reservations[waiter.id] = waiter.hosts
                waiter.continuation.resume()
            } else {
                remaining.append(waiter)
            }
            // A later request for one of these hosts cannot overtake this waiter indefinitely. Requests touching
            // entirely different hosts can still start while it waits.
            occupied.formUnion(waiter.hosts)
        }
        waiters = remaining
    }
}
