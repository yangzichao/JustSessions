import Foundation

final class ThisMacTmuxVersionCheck: @unchecked Sendable {
    static let shared = ThisMacTmuxVersionCheck()
    static let minimumVersion = (major: 3, minor: 3)

    private let lock = NSLock()
    private var answersByExecutablePath: [String: Bool] = [:]

    func answer(forExecutablePath executablePath: String) -> Bool? {
        lock.withLock { answersByExecutablePath[executablePath] }
    }

    @discardableResult
    func check(executablePath: String) -> Bool? {
        guard
            let versionOutput = BoundedProcessRunner.output(
                ofExecutable: executablePath,
                arguments: ["-V"],
                timeout: 5
            )
        else { return nil }
        let answer = Self.isSupported(versionOutput: versionOutput)
        lock.withLock { answersByExecutablePath[executablePath] = answer }
        return answer
    }

    /// `tmux -V` prints e.g. "tmux 3.6a", or "tmux next-3.7" for a build from source.
    static func isSupported(versionOutput: String) -> Bool {
        guard let match = versionOutput.firstMatch(of: #/(\d+)\.(\d+)/#),
            let major = Int(match.1),
            let minor = Int(match.2)
        else { return false }
        return (major, minor) >= minimumVersion
    }
}
