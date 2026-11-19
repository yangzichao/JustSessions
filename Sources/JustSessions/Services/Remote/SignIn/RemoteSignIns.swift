import AppKit
import Observation

@MainActor
@Observable
final class RemoteSignIns {
    static let shared = RemoteSignIns()

    enum State: Equatable {
        case unknown
        case signedIn
        case due
        case signingIn
    }

    let prompter = SSHLoginPrompter()
    private(set) var settings: RemoteSignInSettings
    private(set) var states: [String: State] = [:]
    private(set) var presentingStoreID: ObjectIdentifier?

    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored private let runCheck: @Sendable (_ host: String, _ checkCommand: String) async -> Int32?
    @ObservationIgnored private let makeSession: @Sendable (_ host: String, _ command: String) -> RemoteSignInSession
    @ObservationIgnored private let notify: @MainActor (_ host: String) -> Void
    @ObservationIgnored private let isAppActive: @MainActor () -> Bool
    @ObservationIgnored private let frontStore: @MainActor () -> ConversationStore?
    @ObservationIgnored private var lastCheckedAt: [String: Date] = [:]
    @ObservationIgnored private var hostsBeingChecked: Set<String> = []
    @ObservationIgnored private var lookedAt: Set<String> = []
    @ObservationIgnored private var notified: Set<String> = []
    @ObservationIgnored private var opened: Set<String> = []
    @ObservationIgnored private var signingIn: (host: String, task: Task<Void, Never>)?

    init(
        userDefaults: UserDefaults = .standard,
        runCheck: (@Sendable (_ host: String, _ checkCommand: String) async -> Int32?)? = nil,
        makeSession: (@Sendable (_ host: String, _ command: String) -> RemoteSignInSession)? = nil,
        notify: (@MainActor (_ host: String) -> Void)? = nil,
        isAppActive: (@MainActor () -> Bool)? = nil,
        frontStore: (@MainActor () -> ConversationStore?)? = nil
    ) {
        self.userDefaults = userDefaults
        settings = RemoteSignInSettings.load(from: userDefaults)
        self.runCheck = runCheck ?? Self.runCheckOnHost
        self.makeSession = makeSession ?? { RemoteSignInSession(host: $0, command: $1) }
        self.notify = notify ?? { SessionNotificationCenter.shared.notifySignInNeeded(on: $0) }
        self.isAppActive = isAppActive ?? { NSApp?.isActive ?? false }
        self.frontStore = frontStore ?? Self.storeOfFrontWindow
    }

    func command(on host: String) -> RemoteSignInCommand? {
        settings.command(on: host)
    }

    func state(on host: String) -> State {
        settings.command(on: host) == nil ? .unknown : states[host] ?? .unknown
    }

    func setCommand(_ command: RemoteSignInCommand?, on host: String, needsLogIn: Bool = false, now: Date = .now) {
        settings.setCommand(command, on: host)
        settings.save(to: userDefaults)
        states[host] = nil
        lastCheckedAt[host] = nil
        lookedAt.remove(host)
        notified.remove(host)
        opened.remove(host)
        look(at: host, needsLogIn: needsLogIn, now: now)
    }

    func forget(_ host: String) {
        guard settings.command(on: host) != nil || settings.signedInAt(on: host) != nil else { return }
        settings.forget(host)
        settings.save(to: userDefaults)
        states[host] = nil
        lastCheckedAt[host] = nil
        if signingIn?.host == host { signingIn?.task.cancel() }
    }

    func lookAtHosts(_ hosts: [String], needingLogIn: Set<String>, now: Date = .now) {
        for host in hosts where settings.command(on: host) != nil {
            look(at: host, needsLogIn: needingLogIn.contains(host), now: now)
        }
    }

    func appCameForward() {
        guard signingIn == nil,
            let host = states.keys.sorted().first(where: { states[$0] == .due && !opened.contains($0) })
        else { return }
        openDialog(on: host)
    }

    func signIn(on host: String, presentingIn store: ConversationStore) {
        guard signingIn == nil, let command = settings.command(on: host) else { return }
        let stateBefore = state(on: host)
        states[host] = .signingIn
        opened.insert(host)
        presentingStoreID = ObjectIdentifier(store)
        let session = makeSession(host, command.command)
        let prompter = prompter
        let task = Task { [weak self, weak store] in
            let outcome = await session.run { await prompter.ask($0) }
            self?.finishSignIn(on: host, outcome: outcome, stateBefore: stateBefore, store: store)
        }
        signingIn = (host, task)
    }

    func signInFromNotification(on host: String) {
        NSApp?.activate()
        guard state(on: host) == .due else { return }
        openDialog(on: host)
    }

    private func look(at host: String, needsLogIn: Bool, now: Date) {
        guard let command = settings.command(on: host), states[host] != .signingIn else { return }
        guard let checkCommand = command.checkCommand else {
            let isDue = RemoteSignInSchedule.isSignInDue(
                lastSignedInAt: settings.signedInAt(on: host),
                intervalHours: command.intervalHours,
                now: now
            )
            apply(isDue ? .needsSignIn : .signedIn, on: host)
            return
        }
        guard !needsLogIn, !hostsBeingChecked.contains(host),
            RemoteSignInSchedule.isCheckDue(lastCheckedAt: lastCheckedAt[host], now: now)
        else { return }
        hostsBeingChecked.insert(host)
        lastCheckedAt[host] = now
        let runCheck = runCheck
        Task { [weak self] in
            let exitStatus = await runCheck(host, checkCommand)
            guard let self else { return }
            hostsBeingChecked.remove(host)
            guard settings.command(on: host)?.checkCommand == checkCommand else { return }
            apply(RemoteSignInSchedule.checkResult(exitStatus: exitStatus), on: host)
        }
    }

    private func apply(_ result: RemoteSignInSchedule.CheckResult, on host: String) {
        guard states[host] != .signingIn, result != .unknown else { return }
        let isFirstLook = lookedAt.insert(host).inserted
        guard result == .needsSignIn else {
            states[host] = .signedIn
            notified.remove(host)
            opened.remove(host)
            return
        }
        let cameDue = states[host] != .due
        states[host] = .due
        guard cameDue else { return }
        switch announcementOfDueSignIn(on: host, isFirstLook: isFirstLook) {
        case .dialog:
            openDialog(on: host)
        case .notification:
            notified.insert(host)
            notify(host)
        case .alreadyNotified:
            break
        }
    }

    private enum DueSignInAnnouncement {
        case dialog
        case notification
        case alreadyNotified
    }

    private func announcementOfDueSignIn(on host: String, isFirstLook: Bool) -> DueSignInAnnouncement {
        let youJustCameToTheApp = isFirstLook && isAppActive()
        if youJustCameToTheApp, signingIn == nil { return .dialog }
        return notified.contains(host) ? .alreadyNotified : .notification
    }

    private func openDialog(on host: String) {
        opened.insert(host)
        guard let store = frontStore() else { return }
        signIn(on: host, presentingIn: store)
    }

    private func finishSignIn(on host: String, outcome: RemoteSignInOutcome, stateBefore: State, store: ConversationStore?) {
        signingIn = nil
        presentingStoreID = nil
        guard settings.command(on: host) != nil else { return }
        switch outcome {
        case .signedIn:
            let now = Date.now
            settings.noteSignedIn(on: host, at: now)
            settings.save(to: userDefaults)
            lastCheckedAt[host] = now
            states[host] = .signedIn
            notified.remove(host)
            opened.remove(host)
        case .cancelled:
            states[host] = stateBefore
        case .failed(let reason):
            states[host] = .due
            store?.show(StoreAlert(title: AppLocalization.string("Couldn't sign in on \(host)"), message: reason))
        }
    }

    nonisolated private static func runCheckOnHost(_ host: String, _ checkCommand: String) async -> Int32? {
        await Task.detached(priority: .utility) {
            let command = RemoteHostShellStartups.shared.startup(on: host).command(running: checkCommand)
            return RemoteHostCommandRunner().run(host, command, RemoteSignInSchedule.checkTimeout)?.exitStatus
        }.value
    }

    private static func storeOfFrontWindow() -> ConversationStore? {
        let registry = WorkspaceWindowRegistry.shared
        if let keyWindow = NSApp?.keyWindow, let workspace = registry.workspace(withWindowNumber: keyWindow.windowNumber) {
            return workspace.store
        }
        return registry.stores.first
    }
}
