import Foundation

/// Whether an installed tmux is new enough for the tabs' sessions: 3.3 or later has the `-T` client flag and
/// `extended-keys always` they start with. An older tmux would fail every tab, so tabs then run the CLI directly.
/// Each executable is checked once, with `tmux -V`.
final class ThisMacTmuxVersionCheck: @unchecked Sendable {
    static let shared = ThisMacTmuxVersionCheck()
    static let minimumVersion = (major: 3, minor: 3)

    private let lock = NSLock()
    private var answersByExecutablePath: [String: Bool] = [:]

    /// The recorded answer, or nil when the executable has not been checked yet.
    func answer(forExecutablePath executablePath: String) -> Bool? {
        lock.withLock { answersByExecutablePath[executablePath] }
    }

    /// Runs `tmux -V` and records the answer. Returns nil when tmux did not answer, so a later check tries again.
    @discardableResult
    func check(executablePath: String) -> Bool? {
        guard let versionOutput = BoundedProcessRunner.output(
            ofExecutable: executablePath,
            arguments: ["-V"],
            timeout: 5
        ) else { return nil }
        let answer = Self.isSupported(versionOutput: versionOutput)
        lock.withLock { answersByExecutablePath[executablePath] = answer }
        return answer
    }

    /// `tmux -V` prints e.g. "tmux 3.6a", or "tmux next-3.7" for a build from source.
    static func isSupported(versionOutput: String) -> Bool {
        guard let match = versionOutput.firstMatch(of: #/(\d+)\.(\d+)/#),
              let major = Int(match.1),
              let minor = Int(match.2) else { return false }
        return (major, minor) >= minimumVersion
    }
}
