import Darwin
import Foundation

/// Apps launched from Finder or the Dock inherit launchd's minimal environment, not what users set up in their
/// shell rc files: the PATH of nvm, Homebrew, bun, …, or an `SSH_AUTH_SOCK` for 1Password or Secretive. Ask the
/// user's login shell for the real one.
enum LoginShellEnvironment {
    /// Read once per app run. Call `warmUpInBackground()` at launch so the first session doesn't wait. Empty when
    /// the shell could not be read.
    static let cachedVariables: [String: String] = readVariables()

    static var cachedPathDirectories: [String] {
        parsePathDirectories(cachedVariables["PATH"] ?? "")
    }

    static func warmUpInBackground() {
        Task.detached(priority: .utility) { _ = cachedVariables }
    }

    static func readVariables(
        shellPath: String = userLoginShellPath(),
        timeout: TimeInterval = 5
    ) -> [String: String] {
        let outputFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsessions-login-environment-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outputFile) }
        guard !outputFile.path.contains("'") else { return [:] }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        // Login + interactive so both profile and rc files run (nvm usually lives in .zshrc).
        // Write to a file instead of a pipe: a daemon started from an rc file can keep a pipe
        // open forever, but it can't stop us from reading a file.
        process.arguments = ["-l", "-i", "-c", "/usr/bin/env -0 > '\(outputFile.path)'"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return [:] }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            // Interactive shells ignore SIGTERM, so a hung rc file needs SIGKILL.
            kill(process.processIdentifier, SIGKILL)
        }

        guard let output = try? Data(contentsOf: outputFile) else { return [:] }
        return parseVariables(output)
    }

    /// `env -0` output: `NAME=value` entries ended by NUL, so a value may hold a newline.
    static func parseVariables(_ output: Data) -> [String: String] {
        output.split(separator: 0).reduce(into: [String: String]()) { variables, entry in
            guard let text = String(data: Data(entry), encoding: .utf8),
                  let separator = text.firstIndex(of: "="),
                  separator != text.startIndex else { return }
            variables[String(text[..<separator])] = String(text[text.index(after: separator)...])
        }
    }

    /// Keeps absolute entries only; a relative entry like "." would make lookup depend on the cwd.
    static func parsePathDirectories(_ pathValue: String) -> [String] {
        pathValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")
            .map(String.init)
            .filter { $0.hasPrefix("/") }
    }

    static func userLoginShellPath() -> String {
        if let passwordEntry = getpwuid(getuid()), let shell = passwordEntry.pointee.pw_shell {
            let shellPath = String(cString: shell)
            if FileManager.default.isExecutableFile(atPath: shellPath) { return shellPath }
        }
        if let shellPath = ProcessInfo.processInfo.environment["SHELL"],
           FileManager.default.isExecutableFile(atPath: shellPath) {
            return shellPath
        }
        return "/bin/zsh"
    }
}
