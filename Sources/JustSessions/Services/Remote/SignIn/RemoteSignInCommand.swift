import Foundation

/// A command that signs in again on an SSH host, such as one that renews a credential which expires and asks for a
/// PIN or a one-time code. The app runs it on the host when it's due, and asks its questions in a dialog; see
/// `RemoteSignIns`.
struct RemoteSignInCommand: Codable, Equatable, Sendable {
    /// The choices the sheet offers for how often to sign in when there's no check command.
    static let intervalChoices = [4, 8, 10, 12, 24]
    static let defaultIntervalHours = 10

    /// Run on the host through its login shell, with a terminal, as you'd type it there.
    let command: String
    /// Run on the host without a terminal every few minutes; any exit status but 0 means a sign-in is due. Nil signs
    /// in every `intervalHours` instead.
    let checkCommand: String?
    /// How long a sign-in lasts when there's no check command.
    let intervalHours: Int

    /// Nil for an empty command; an empty check command is none.
    init?(command: String, checkCommand: String? = nil, intervalHours: Int = defaultIntervalHours) {
        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }
        self.command = command
        let checkCommand = checkCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.checkCommand = checkCommand.isEmpty ? nil : checkCommand
        self.intervalHours = max(1, intervalHours)
    }
}

/// Each SSH host's sign-in command, and when the app last signed in with it, kept in settings.
struct RemoteSignInSettings: Equatable {
    static let commandsKey = "remoteSignInCommands"
    static let signedInKey = "remoteSignInSucceededAt"

    private(set) var commandsByHost: [String: RemoteSignInCommand] = [:]
    /// When each host's sign-in command last succeeded through the app.
    private(set) var signedInAtByHost: [String: Date] = [:]

    static func load(from userDefaults: UserDefaults) -> RemoteSignInSettings {
        var settings = RemoteSignInSettings()
        if let data = userDefaults.data(forKey: commandsKey),
            let commands = try? JSONDecoder().decode([String: RemoteSignInCommand].self, from: data)
        {
            settings.commandsByHost = commands
        }
        settings.signedInAtByHost = userDefaults.dictionary(forKey: signedInKey) as? [String: Date] ?? [:]
        return settings
    }

    func save(to userDefaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(commandsByHost) { userDefaults.set(data, forKey: Self.commandsKey) }
        userDefaults.set(signedInAtByHost, forKey: Self.signedInKey)
    }

    func command(on host: String) -> RemoteSignInCommand? {
        commandsByHost[host]
    }

    func signedInAt(on host: String) -> Date? {
        signedInAtByHost[host]
    }

    /// Nil removes the host's command. A changed command forgets when the old one last signed in.
    mutating func setCommand(_ command: RemoteSignInCommand?, on host: String) {
        if commandsByHost[host]?.command != command?.command { signedInAtByHost.removeValue(forKey: host) }
        commandsByHost[host] = command
    }

    mutating func noteSignedIn(on host: String, at date: Date) {
        signedInAtByHost[host] = date
    }

    /// For a removed host.
    mutating func forget(_ host: String) {
        commandsByHost.removeValue(forKey: host)
        signedInAtByHost.removeValue(forKey: host)
    }
}

/// When a host's sign-in is due.
enum RemoteSignInSchedule {
    /// How often a host's check command runs.
    static let checkInterval: TimeInterval = 5 * 60
    /// How long a check command may take; one that takes longer tells nothing.
    static let checkTimeout: TimeInterval = 30

    enum CheckResult: Equatable {
        case signedIn
        case needsSignIn
        /// The host couldn't be reached, or the check didn't finish in time.
        case unknown
    }

    static func isCheckDue(lastCheckedAt: Date?, now: Date) -> Bool {
        lastCheckedAt.map { now.timeIntervalSince($0) >= checkInterval } ?? true
    }

    /// With no check command: due until the first sign-in through the app, then every `intervalHours`.
    static func isSignInDue(lastSignedInAt: Date?, intervalHours: Int, now: Date) -> Bool {
        lastSignedInAt.map { now.timeIntervalSince($0) >= TimeInterval(intervalHours) * 3600 } ?? true
    }

    /// `ssh` exits with 255 when it can't connect, and a check that timed out has no status.
    static func checkResult(exitStatus: Int32?) -> CheckResult {
        switch exitStatus {
        case 0?: .signedIn
        case nil, RemoteHostCommandRunner.connectionFailureExitStatus?: .unknown
        default: .needsSignIn
        }
    }
}
