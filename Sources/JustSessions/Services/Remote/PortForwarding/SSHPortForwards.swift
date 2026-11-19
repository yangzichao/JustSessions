import AppKit
import Observation

@MainActor
@Observable
final class SSHPortForwards {
    static let shared = SSHPortForwards()

    static let loginCheckInterval: TimeInterval = 5

    enum State: Hashable {
        case active
        case reconnecting
        case connectionLost(String)
        case failed(String)
    }

    struct Entry: Identifiable, Hashable {
        let forward: SSHPortForward
        var state: State
        var id: Int { forward.localPort }
    }

    private(set) var entries: [Entry] = []

    private enum Route: Sendable {
        case connection(SSHPortForwardConnection)
        case login(controlPath: String)

        var controlPath: String {
            switch self {
            case .connection(let connection): connection.controlPath
            case .login(let controlPath): controlPath
            }
        }

        func newOutput() -> String? {
            guard case .connection(let connection) = self else { return nil }
            return connection.output.newText()
        }
    }

    private enum RouteOutcome {
        case connected(Route)
        case failed(SSHConnectionProblem)
    }

    private let sshExecutable: String
    private let socketRoot: String
    private let loginConnections: SSHLoginConnections
    private let isLocalPortFree: @Sendable (Int) -> Bool
    private let currentDate: () -> Date
    private let sleepUntilWakeUp: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var routes: [String: Route] = [:]
    @ObservationIgnored private var connecting: [String: Task<RouteOutcome, Never>] = [:]
    @ObservationIgnored private var forwardsBeingAdded: [String: Int] = [:]
    @ObservationIgnored private var localPortsBeingAdded: Set<Int> = []
    @ObservationIgnored private var schedule = RemoteTabReconnectSchedule()
    @ObservationIgnored private(set) var hostsBeingReconnected: Set<String> = []
    @ObservationIgnored private var wakeUp: Task<Void, Never>?
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []

    init(
        sshExecutable: String = "/usr/bin/ssh",
        socketRoot: String = SSHConnectionSharing.socketRoot,
        loginConnections: SSHLoginConnections = .shared,
        isLocalPortFree: @escaping @Sendable (Int) -> Bool = LocalPortAvailability.isFree,
        currentDate: @escaping () -> Date = Date.init,
        sleepUntilWakeUp: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.sshExecutable = sshExecutable
        self.socketRoot = socketRoot
        self.loginConnections = loginConnections
        self.isLocalPortFree = isLocalPortFree
        self.currentDate = currentDate
        self.sleepUntilWakeUp = sleepUntilWakeUp
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.tryAgain() }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.tryAgain() }
            },
            center.addObserver(
                forName: RemoteTabReconnector.loginOpenedNotification, object: nil, queue: .main
            ) { [weak self] notification in
                guard let host = notification.object as? String else { return }
                MainActor.assumeIsolated { self?.tryAgain(onlyOn: host) }
            },
        ]
    }

    func entries(on host: String) -> [Entry] {
        entries.filter { $0.forward.host == host }
    }

    func forward(remotePort: Int, localPort: Int, on host: String) async -> SSHPortForwardFailure? {
        guard SSHPortForward.validPorts.contains(remotePort), SSHPortForward.validPorts.contains(localPort) else {
            return .invalidPort
        }
        let forward = SSHPortForward(host: host, localPort: localPort, remotePort: remotePort)
        if let existing = entries.first(where: { $0.forward.localPort == localPort })?.forward {
            return .localPortForwardedAlready(existing)
        }
        guard localPortsBeingAdded.insert(localPort).inserted else { return .localPortForwardedAlready(forward) }
        forwardsBeingAdded[host, default: 0] += 1
        defer {
            localPortsBeingAdded.remove(localPort)
            forwardsBeingAdded[host, default: 1] -= 1
            if forwardsBeingAdded[host] == 0 { forwardsBeingAdded.removeValue(forKey: host) }
            endRouteIfUnused(host)
        }

        let hostRoute: Route
        switch await route(to: host) {
        case .failed(let problem):
            return .couldNotConnect(host: host, problem)
        case .connected(let connectedRoute):
            hostRoute = connectedRoute
        }
        if let failure = await add(forward, through: hostRoute, probing: true) { return failure }
        if isCurrent(hostRoute, of: host) {
            entries.append(Entry(forward: forward, state: .active))
        } else if schedule.hostsBeingTried.contains(host) {
            entries.append(Entry(forward: forward, state: .reconnecting))
        } else {
            return .couldNotConnect(host: host, .connectionLost)
        }
        return nil
    }

    func stop(_ forward: SSHPortForward) {
        guard entries.contains(where: { $0.forward == forward }) else { return }
        entries.removeAll { $0.forward == forward }
        if let route = routes[forward.host] { cancelInBackground([forward], through: route) }
        endRouteIfUnused(forward.host)
    }

    func stopAll(on host: String) {
        let forwards = entries(on: host).map(\.forward)
        entries.removeAll { $0.forward.host == host }
        if let route = routes[host] { cancelInBackground(forwards, through: route) }
        endRoute(host)
    }

    func loginEnding(on host: String) {
        guard case .login = routes[host] else { return }
        entries.removeAll { $0.forward.host == host }
        endRoute(host)
    }

    func endAll() {
        wakeUp?.cancel()
        for case .connection(let connection) in routes.values { connection.end() }
        routes.removeAll()
        entries.removeAll()
        schedule = RemoteTabReconnectSchedule()
    }

    func tryAgain(onlyOn onlyHost: String? = nil) {
        let now = currentDate()
        var hosts: Set<String> = []
        for index in entries.indices where entries[index].state != .active {
            let host = entries[index].forward.host
            guard onlyHost == nil || host == onlyHost else { continue }
            if case .connectionLost = entries[index].state { entries[index].state = .reconnecting }
            hosts.insert(host)
        }
        for host in hosts { schedule.startTrying(host, now: now) }
        scheduleWakeUp()
    }

    func askDueHosts() {
        for (host, route) in routes where !isCurrent(route, of: host) {
            routes.removeValue(forKey: host)
            connectionDropped(on: host)
        }
        let now = currentDate()
        for host in schedule.hostsBeingTried where schedule.isDue(host, now: now) && !hostsBeingReconnected.contains(host) {
            hostsBeingReconnected.insert(host)
            Task {
                await reconnect(host)
                hostsBeingReconnected.remove(host)
                scheduleWakeUp()
            }
        }
        scheduleWakeUp()
    }

    private func route(to host: String) async -> RouteOutcome {
        if let route = routes[host], isCurrent(route, of: host) { return .connected(route) }
        if let loginControlPath = loginConnections.controlPath(for: host) {
            let route = Route.login(controlPath: loginControlPath)
            routes[host] = route
            scheduleWakeUp()
            return .connected(route)
        }
        if let connecting = connecting[host] { return await connecting.value }
        let sshExecutable = sshExecutable
        let socketRoot = socketRoot
        let endedOnItsOwn: @Sendable (SSHPortForwardConnection) -> Void = { [weak self] connection in
            Task { @MainActor in self?.connectionEndedOnItsOwn(connection) }
        }
        let task = Task { () -> RouteOutcome in
            let outcome = await Task.detached(priority: .userInitiated) {
                SSHPortForwardConnection.start(
                    to: host,
                    sshExecutable: sshExecutable,
                    socketRoot: socketRoot,
                    onEndOnItsOwn: endedOnItsOwn
                )
            }.value
            connecting.removeValue(forKey: host)
            switch outcome {
            case .failed(let problem):
                return .failed(problem)
            case .started(let connection):
                let route = Route.connection(connection)
                routes[host] = route
                return .connected(route)
            }
        }
        connecting[host] = task
        return await task.value
    }

    private func isCurrent(_ route: Route, of host: String) -> Bool {
        switch route {
        case .connection(let connection):
            guard case .connection(let current) = routes[host], current === connection else { return false }
            return connection.isOpen
        case .login(let controlPath):
            guard case .login(let currentControlPath) = routes[host], currentControlPath == controlPath else { return false }
            return loginConnections.controlPath(for: host) == controlPath
        }
    }

    private func connectionEndedOnItsOwn(_ connection: SSHPortForwardConnection) {
        guard case .connection(let current) = routes[connection.host], current === connection else { return }
        routes.removeValue(forKey: connection.host)
        connectionDropped(on: connection.host)
    }

    private func connectionDropped(on host: String) {
        guard entries.contains(where: { $0.forward.host == host }) else { return }
        for index in entries.indices where entries[index].forward.host == host {
            entries[index].state = .reconnecting
        }
        schedule.startTrying(host, now: currentDate())
        scheduleWakeUp()
    }

    private func reconnect(_ host: String) async {
        guard entries.contains(where: { $0.forward.host == host && $0.state != .active }) else {
            schedule.stopTrying(host)
            return
        }
        forwardsBeingAdded[host, default: 0] += 1
        defer {
            forwardsBeingAdded[host, default: 1] -= 1
            if forwardsBeingAdded[host] == 0 { forwardsBeingAdded.removeValue(forKey: host) }
            endRouteIfUnused(host)
        }
        switch await route(to: host) {
        case .failed(let problem):
            guard !schedule.noteFailure(on: host, now: currentDate()) else { return }
            for index in entries.indices where entries[index].forward.host == host && entries[index].state != .active {
                entries[index].state = .connectionLost(problem.explanation(host: host))
            }
        case .connected(let route):
            schedule.stopTrying(host)
            for forward in entries.filter({ $0.forward.host == host && $0.state != .active }).map(\.forward) {
                let failure = await add(forward, through: route, probing: false)
                guard let index = entries.firstIndex(where: { $0.forward == forward }) else {
                    if failure == nil { cancelInBackground([forward], through: route) }
                    continue
                }
                entries[index].state = failure.map { .failed($0.message) } ?? .active
            }
        }
    }

    private func endRouteIfUnused(_ host: String) {
        guard !entries.contains(where: { $0.forward.host == host }), forwardsBeingAdded[host] == nil else { return }
        endRoute(host)
    }

    private func endRoute(_ host: String) {
        schedule.stopTrying(host)
        guard let route = routes.removeValue(forKey: host) else { return }
        if case .connection(let connection) = route {
            Task.detached(priority: .utility) { connection.end() }
        }
        scheduleWakeUp()
    }

    private func scheduleWakeUp() {
        wakeUp?.cancel()
        wakeUp = nil
        var next = schedule.nextTryAt(excluding: hostsBeingReconnected)
        if routes.values.contains(where: { if case .login = $0 { true } else { false } }) {
            let loginCheck = currentDate().addingTimeInterval(Self.loginCheckInterval)
            next = min(next ?? loginCheck, loginCheck)
        }
        guard let next else { return }
        let delay = max(next.timeIntervalSince(currentDate()), 0)
        let sleepUntilWakeUp = sleepUntilWakeUp
        wakeUp = Task { [weak self] in
            try? await sleepUntilWakeUp(.seconds(delay))
            guard !Task.isCancelled else { return }
            self?.askDueHosts()
        }
    }

    private func add(_ forward: SSHPortForward, through route: Route, probing: Bool) async -> SSHPortForwardFailure? {
        let sshExecutable = sshExecutable
        let isLocalPortFree = isLocalPortFree
        return await Task.detached(priority: .userInitiated) {
            Self.add(
                forward,
                through: route,
                probing: probing,
                sshExecutable: sshExecutable,
                isLocalPortFree: isLocalPortFree
            )
        }.value
    }

    private nonisolated static func add(
        _ forward: SSHPortForward,
        through route: Route,
        probing: Bool,
        sshExecutable: String,
        isLocalPortFree: (Int) -> Bool
    ) -> SSHPortForwardFailure? {
        _ = route.newOutput()
        let result = BoundedProcessRunner.result(
            ofExecutable: sshExecutable,
            arguments: SSHPortForwardCommands.requestArguments(.forward, forward, controlPath: route.controlPath),
            environment: SSHProcessEnvironment.standard,
            includesStandardError: true,
            timeout: 10
        )
        guard let result, result.exitStatus == 0 else {
            // The connection says why; `ssh -O forward` itself only says that it failed.
            let sshMessage = route.newOutput() ?? nonEmptyLines(of: result?.output ?? "") ?? "ssh didn't answer."
            if !isLocalPortFree(forward.localPort) { return .localPortInUse(port: forward.localPort, sshMessage: sshMessage) }
            return .refused(sshMessage: sshMessage)
        }
        guard probing else { return nil }
        switch SSHPortForwardProbe.run(forward, controlPath: route.controlPath, sshExecutable: sshExecutable) {
        case .couldNotStart, .reachedPort, .stillOpenAtTimeout:
            return nil
        case .failed(let probeOutput):
            guard let refusal = refusal(in: route.newOutput() ?? probeOutput) else { return nil }
            cancel([forward], through: route, sshExecutable: sshExecutable)
            return .refusedByHost(host: forward.host, sshMessage: refusal)
        }
    }

    /// The line of a failed probe that says the host refused to open the port, such as "administratively
    /// prohibited". Nil when nothing listens on the port, as a program may start doing later, and when the reason
    /// can't be read, as through a login, whose `ssh` says only "Session open refused by peer".
    nonisolated static func refusal(in output: String) -> String? {
        output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.contains("open failed") && !$0.contains("Connection refused") }
    }

    private nonisolated static func nonEmptyLines(of output: String) -> String? {
        let lines = output.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private func cancelInBackground(_ forwards: [SSHPortForward], through route: Route) {
        guard !forwards.isEmpty else { return }
        let sshExecutable = sshExecutable
        Task.detached(priority: .utility) { Self.cancel(forwards, through: route, sshExecutable: sshExecutable) }
    }

    private nonisolated static func cancel(_ forwards: [SSHPortForward], through route: Route, sshExecutable: String) {
        for forward in forwards {
            _ = BoundedProcessRunner.result(
                ofExecutable: sshExecutable,
                arguments: SSHPortForwardCommands.requestArguments(.cancel, forward, controlPath: route.controlPath),
                environment: SSHProcessEnvironment.standard,
                includesStandardError: true,
                timeout: 10
            )
        }
    }
}
