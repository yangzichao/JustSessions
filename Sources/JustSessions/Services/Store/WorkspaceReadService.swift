import Combine
import Foundation

/// Read-heavy workspace state shared by every window. Window presentation and terminal state stay in each
/// `ConversationStore`; session discovery and message text do not need a copy per window.
@MainActor
final class WorkspaceReadService: ObservableObject {
    struct ThisMacDiscovery: Sendable {
        let conversations: [Conversation]
        let failures: [String]
        let installedProviders: Set<ConversationProvider>
        let tmuxPaneProcessIDs: [String: Int32]
    }

    let messageIndexer: SessionMessageIndexer
    let adapters: [any ConversationAdapter]
    let commandResolver: NativeCLICommandResolver
    private let discovery = ThisMacDiscoveryCoordinator()

    init(
        adapters: [any ConversationAdapter] = [
            ClaudeAdapter(), CodexAdapter(), AntigravityAdapter(), KiroAdapter(), OpenCodeAdapter(), PiAdapter(),
        ],
        commandResolver: NativeCLICommandResolver = NativeCLICommandResolver(),
        messageIndexer: SessionMessageIndexer = SessionMessageIndexer()
    ) {
        self.adapters = adapters
        self.commandResolver = commandResolver
        self.messageIndexer = messageIndexer
    }

    /// Joins a scan already in flight. Each caller is a waiter; when the final waiter cancels, that producer is
    /// evicted so a later window starts fresh.
    func discoverThisMac(coordinatingWith hostWork: HostSessionWorkCoordinator? = nil) async throws -> ThisMacDiscovery {
        try await discovery.discover(adapters: adapters, commandResolver: commandResolver, hostWork: hostWork)
    }

    /// How many windows wait on the scan in flight. A window's refresh joins from a task of its own, so this tells a
    /// test when it has.
    func thisMacDiscoveryWaiterCount() async -> Int {
        await discovery.waiterCount
    }
}

private actor ThisMacDiscoveryCoordinator {
    typealias Discovery = WorkspaceReadService.ThisMacDiscovery
    private typealias Continuation = CheckedContinuation<Discovery, any Error>

    private struct Waiter {
        let continuation: Continuation
        let cancellation: DiscoveryWaiterCancellation
    }

    private struct ProducerResult: Sendable {
        let discovery: Discovery
        let tmuxServer: ThisMacTmuxServer?
    }

    private struct InFlight {
        let generation: Int
        let task: Task<ProducerResult, Never>
        let commandResolver: NativeCLICommandResolver
        var waiters: [UUID: Waiter]
    }

    private var inFlight: InFlight?

    var waiterCount: Int { inFlight?.waiters.count ?? 0 }

    func discover(adapters: [any ConversationAdapter], commandResolver: NativeCLICommandResolver,
                  hostWork: HostSessionWorkCoordinator?) async throws -> Discovery {
        let waiterID = UUID()
        let cancellation = DiscoveryWaiterCancellation()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                addWaiter(
                    waiterID,
                    continuation: continuation,
                    cancellation: cancellation,
                    adapters: adapters,
                    commandResolver: commandResolver,
                    hostWork: hostWork
                )
            }
        } onCancel: {
            // This mark is synchronous and visible to `addWaiter`, even before the actor processes cleanup.
            cancellation.cancel()
            Task { await self.cancelWaiter(waiterID) }
        }
    }

    private func addWaiter(
        _ waiterID: UUID,
        continuation: Continuation,
        cancellation: DiscoveryWaiterCancellation,
        adapters: [any ConversationAdapter],
        commandResolver: NativeCLICommandResolver,
        hostWork: HostSessionWorkCoordinator?
    ) {
        removeCancelledWaiters()
        guard !cancellation.isCancelled else {
            continuation.resume(throwing: CancellationError())
            return
        }
        if var inFlight {
            inFlight.waiters[waiterID] = Waiter(continuation: continuation, cancellation: cancellation)
            self.inFlight = inFlight
            return
        }

        let generation = commandResolver.beginThisMacTmuxProbeGeneration()
        let task = Task.detached(priority: .userInitiated) {
            if let hostWork {
                do {
                    return try await hostWork.withAccess(to: [.thisMac]) {
                        await Self.scan(adapters: adapters, commandResolver: commandResolver)
                    }
                } catch { return Self.cancelledResult() }
            }
            return await Self.scan(adapters: adapters, commandResolver: commandResolver)
        }
        inFlight = InFlight(
            generation: generation,
            task: task,
            commandResolver: commandResolver,
            waiters: [waiterID: Waiter(continuation: continuation, cancellation: cancellation)]
        )
        Task { [weak self] in
            let result = await task.value
            await self?.producerFinished(generation: generation, result: result)
        }
    }

    private func cancelWaiter(_ waiterID: UUID) {
        guard inFlight?.waiters[waiterID] != nil else { return }
        removeCancelledWaiters()
    }

    /// Removes synchronously marked waiters before a new caller can join their producer.
    private func removeCancelledWaiters() {
        guard var inFlight else { return }
        let cancelledIDs = inFlight.waiters.compactMap { id, waiter in
            waiter.cancellation.isCancelled ? id : nil
        }
        for id in cancelledIDs {
            inFlight.waiters.removeValue(forKey: id)?.continuation.resume(throwing: CancellationError())
        }
        guard !inFlight.waiters.isEmpty else {
            inFlight.task.cancel()
            self.inFlight = nil
            return
        }
        self.inFlight = inFlight
    }

    private func producerFinished(generation: Int, result: ProducerResult) {
        removeCancelledWaiters()
        guard let inFlight, inFlight.generation == generation else { return }
        _ = inFlight.commandResolver.commitThisMacTmuxServer(result.tmuxServer, generation: generation)
        self.inFlight = nil
        for waiter in inFlight.waiters.values { waiter.continuation.resume(returning: result.discovery) }
    }

    private nonisolated static func scan(
        adapters: [any ConversationAdapter], commandResolver: NativeCLICommandResolver
    ) async -> ProducerResult {
        let cancellation = ConversationDiscoveryCancellation { Task.isCancelled }
        var found: [Conversation] = []
        var failures: [String] = []
        for adapter in adapters {
            do {
                try cancellation.checkCancellation()
                found += try adapter.discover(cancellation: cancellation)
            } catch is CancellationError {
                return cancelledResult()
            } catch {
                failures.append("\(adapter.provider.rawValue): \(error.localizedDescription)")
            }
        }
        do {
            let installedProviders = try InstalledCLIs.onThisMac(
                commandResolver: commandResolver,
                cancellation: cancellation
            )
            try cancellation.checkCancellation()
            // Version and tmux-server process probes have finite timeouts. Probing does not change the selected
            // server; only `producerFinished` may commit, after checking this discovery generation is still current.
            let tmuxServer = commandResolver.probeThisMacTmuxServer()
            try cancellation.checkCancellation()
            let tmuxPaneProcessIDs = tmuxServer?.appSessionPaneProcessIDs() ?? [:]
            try cancellation.checkCancellation()
            return ProducerResult(
                discovery: Discovery(
                    conversations: found,
                    failures: failures,
                    installedProviders: installedProviders,
                    tmuxPaneProcessIDs: tmuxPaneProcessIDs
                ),
                tmuxServer: tmuxServer
            )
        } catch {
            return cancelledResult()
        }
    }

    private nonisolated static func cancelledResult() -> ProducerResult {
        ProducerResult(
            discovery: Discovery(conversations: [], failures: [], installedProviders: [], tmuxPaneProcessIDs: [:]),
            tmuxServer: nil
        )
    }
}

private final class DiscoveryWaiterCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }
    func cancel() { lock.withLock { cancelled = true } }
}
