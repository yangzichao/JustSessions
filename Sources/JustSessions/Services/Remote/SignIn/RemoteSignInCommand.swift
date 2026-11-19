import Foundation

struct RemoteSignInCommand: Codable, Equatable, Sendable {
    static let intervalChoices = [4, 8, 10, 12, 24]
    static let defaultIntervalHours = 10

    let command: String
    let checkCommand: String?
    let intervalHours: Int

    init?(command: String, checkCommand: String? = nil, intervalHours: Int = defaultIntervalHours) {
        let command = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return nil }
        self.command = command
        let checkCommand = checkCommand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.checkCommand = checkCommand.isEmpty ? nil : checkCommand
        self.intervalHours = max(1, intervalHours)
    }
}

struct RemoteSignInSettings: Equatable {
    static let commandsKey = "remoteSignInCommands"
    static let signedInKey = "remoteSignInSucceededAt"

    private(set) var commandsByHost: [String: RemoteSignInCommand] = [:]
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

    mutating func setCommand(_ command: RemoteSignInCommand?, on host: String) {
        if commandsByHost[host]?.command != command?.command { signedInAtByHost.removeValue(forKey: host) }
        commandsByHost[host] = command
    }

    mutating func noteSignedIn(on host: String, at date: Date) {
        signedInAtByHost[host] = date
    }

    mutating func forget(_ host: String) {
        commandsByHost.removeValue(forKey: host)
        signedInAtByHost.removeValue(forKey: host)
    }
}

enum RemoteSignInSchedule {
    static let checkInterval: TimeInterval = 5 * 60
    static let checkTimeout: TimeInterval = 30

    enum CheckResult: Equatable {
        case signedIn
        case needsSignIn
        case unknown
    }

    static func isCheckDue(lastCheckedAt: Date?, now: Date) -> Bool {
        lastCheckedAt.map { now.timeIntervalSince($0) >= checkInterval } ?? true
    }

    static func isSignInDue(lastSignedInAt: Date?, intervalHours: Int, now: Date) -> Bool {
        lastSignedInAt.map { now.timeIntervalSince($0) >= TimeInterval(intervalHours) * 3600 } ?? true
    }

    static func checkResult(exitStatus: Int32?) -> CheckResult {
        switch exitStatus {
        case 0?: .signedIn
        case nil, RemoteHostCommandRunner.connectionFailureExitStatus?: .unknown
        default: .needsSignIn
        }
    }
}
